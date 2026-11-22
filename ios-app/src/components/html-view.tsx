import type { ReactNode } from 'react';
import { Linking, ScrollView, Text, View, type TextStyle } from 'react-native';

import { Radius, Spacing } from '@/constants/theme';
import { useTheme } from '@/hooks/use-theme';

type Node = { tag: string; attrs: Record<string, string>; children: Node[] } | string;
type Theme = ReturnType<typeof useTheme>;

const VOID = new Set(['br', 'hr', 'img', 'meta', 'link', 'input', 'col', 'wbr']);
const DROP = new Set(['script', 'style', 'head', 'title', 'img', 'iframe', 'object', 'svg', 'button', 'form']);
const BLOCK = new Set([
  'p', 'div', 'section', 'article', 'header', 'footer', 'main', 'blockquote', 'center',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'hr', 'pre', 'dl', 'dt', 'dd',
]);
const ENTITIES: Record<string, string> = {
  nbsp: ' ', amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", ndash: '-', mdash: '-', hellip: '…',
  laquo: '«', raquo: '»', bdquo: '„', rdquo: '”', ldquo: '“', copy: '©', euro: '€', deg: '°',
  aacute: 'á', eacute: 'é', iacute: 'í', oacute: 'ó', uacute: 'ú', ouml: 'ö', uuml: 'ü', odblac: 'ő', udblac: 'ű',
  Aacute: 'Á', Eacute: 'É', Iacute: 'Í', Oacute: 'Ó', Uacute: 'Ú', Ouml: 'Ö', Uuml: 'Ü', Odblac: 'Ő', Udblac: 'Ű',
  auml: 'ä', Auml: 'Ä', szlig: 'ß',
};
const URL_RE = /(https?:\/\/[^\s<>"')]+|www\.[^\s<>"')]+)/g;

function decode(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
    if (e[0] === '#') {
      const code = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
      return Number.isFinite(code) && code > 0 && code < 0x110000 ? String.fromCodePoint(code) : '';
    }
    return ENTITIES[e] ?? m;
  });
}

function parseAttrs(raw: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const m of raw.matchAll(/([a-zA-Z-:]+)\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))/g)) {
    out[m[1].toLowerCase()] = decode(m[3] ?? m[4] ?? m[5] ?? '');
  }
  return out;
}

export function parseHtml(html: string): Node[] {
  const root: Node = { tag: 'root', attrs: {}, children: [] };
  const stack = [root];
  const clean = html.replace(/<!--[\s\S]*?-->/g, '').replace(/<(script|style)[\s\S]*?<\/\1>/gi, '');
  for (const m of clean.matchAll(/<(\/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>|([^<]+)/g)) {
    const top = stack[stack.length - 1] as Exclude<Node, string>;
    if (m[4] !== undefined) {
      top.children.push(decode(m[4]));
      continue;
    }
    const tag = m[2].toLowerCase();
    if (m[1]) {
      const at = stack.map((n) => (typeof n === 'string' ? '' : n.tag)).lastIndexOf(tag);
      if (at > 0) stack.length = at;
      continue;
    }
    const node: Node = { tag, attrs: parseAttrs(m[3]), children: [] };
    top.children.push(node);
    if (!VOID.has(tag) && !m[3].trim().endsWith('/')) stack.push(node);
  }
  return (root as Exclude<Node, string>).children;
}

function inlineStyle(tag: string, attrs: Record<string, string>, c: Theme): TextStyle {
  const css = (attrs.style ?? '').toLowerCase();
  const s: { -readonly [K in keyof TextStyle]: TextStyle[K] } = {};
  if (tag === 'b' || tag === 'strong' || tag === 'th' || /font-weight:\s*(bold|[6-9]00)/.test(css)) s.fontWeight = '700';
  if (tag === 'i' || tag === 'em' || /font-style:\s*italic/.test(css)) s.fontStyle = 'italic';
  if (tag === 'u' || tag === 'ins' || /text-decoration:[^;]*underline/.test(css)) s.textDecorationLine = 'underline';
  if (tag === 's' || tag === 'strike' || tag === 'del') s.textDecorationLine = 'line-through';
  if (tag === 'code' || tag === 'pre') s.fontFamily = 'Menlo';
  if (tag === 'small' || tag === 'sub' || tag === 'sup') s.fontSize = 12;
  if (tag === 'mark') s.backgroundColor = c.warningSubtle;
  return s;
}

function safeHref(href: string | undefined): string | null {
  if (!href) return null;
  const h = href.trim();
  if (/^(https?:|mailto:|tel:)/i.test(h)) return h;
  if (/^www\./i.test(h)) return `https://${h}`;
  return null;
}

function linkify(text: string, key: string, c: Theme) {
  const parts = text.split(URL_RE);
  if (parts.length === 1) return text;
  return parts.map((p, i) =>
    i % 2 === 1 ? (
      <Text key={`${key}-u${i}`} style={{ color: c.brand, textDecorationLine: 'underline' }} onPress={() => void Linking.openURL(safeHref(p) ?? p)}>
        {p}
      </Text>
    ) : (
      p
    ),
  );
}

function isBlock(n: Node): boolean {
  return typeof n !== 'string' && (BLOCK.has(n.tag) || n.tag === 'tr' || n.tag === 'br-block');
}

function renderInline(nodes: Node[], c: Theme, key: string, inLink = false): ReactNode[] {
  return nodes.map((n, i) => {
    const k = `${key}-${i}`;
    if (typeof n === 'string') return inLink ? n.replace(/\s+/g, ' ') : linkify(n.replace(/\s+/g, ' '), k, c);
    if (DROP.has(n.tag)) return null;
    if (n.tag === 'br') return '\n';
    if (n.tag === 'a') {
      const href = safeHref(n.attrs.href);
      return (
        <Text
          key={k}
          style={href ? { color: c.brand, textDecorationLine: 'underline' } : undefined}
          onPress={href ? () => void Linking.openURL(href) : undefined}>
          {renderInline(n.children, c, k, true)}
        </Text>
      );
    }
    return (
      <Text key={k} style={inlineStyle(n.tag, n.attrs, c)}>
        {renderInline(n.children, c, k, inLink)}
      </Text>
    );
  });
}

function textOf(n: Node): string {
  return typeof n === 'string' ? n : n.children.map(textOf).join('');
}

function Table({ node, c, k }: { node: Exclude<Node, string>; c: Theme; k: string }) {
  const rows: Exclude<Node, string>[] = [];
  const walk = (n: Node) => {
    if (typeof n === 'string') return;
    if (n.tag === 'tr') rows.push(n);
    else n.children.forEach(walk);
  };
  walk(node);
  const grid = rows.map((r) => r.children.filter((x): x is Exclude<Node, string> => typeof x !== 'string' && (x.tag === 'td' || x.tag === 'th')));
  const cols = Math.max(0, ...grid.map((r) => r.length));
  if (!cols) return null;
  const widths = Array.from({ length: cols }, (_, ci) => {
    const longest = Math.max(...grid.map((r) => (r[ci] ? textOf(r[ci]).trim().length : 0)));
    return Math.min(240, Math.max(72, longest * 7.6 + 20));
  });
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginVertical: Spacing.one }}>
      <View style={{ borderRadius: Radius.md, borderCurve: 'continuous', overflow: 'hidden', borderWidth: 0.5, borderColor: c.separator }}>
        {grid.map((cells, ri) => {
          const head = cells.length > 0 && cells.every((x) => x.tag === 'th');
          return (
            <View key={`${k}-r${ri}`} style={{ flexDirection: 'row', backgroundColor: head ? c.brandSubtle : ri % 2 ? c.fill : 'transparent' }}>
              {Array.from({ length: cols }, (_, ci) => {
                const cell = cells[ci];
                return (
                  <View
                    key={ci}
                    style={{
                      width: widths[ci],
                      paddingHorizontal: 8,
                      paddingVertical: 6,
                      borderLeftWidth: ci ? 0.5 : 0,
                      borderTopWidth: ri ? 0.5 : 0,
                      borderColor: c.separator,
                    }}>
                    <Text selectable style={{ color: c.text, fontSize: 13, lineHeight: 18, fontWeight: head ? '700' : '400' }}>
                      {cell ? renderInline(cell.children, c, `${k}-${ri}-${ci}`) : ''}
                    </Text>
                  </View>
                );
              })}
            </View>
          );
        })}
      </View>
    </ScrollView>
  );
}

const HEADING: Record<string, number> = { h1: 22, h2: 20, h3: 18, h4: 16, h5: 15, h6: 15 };

function Blocks({ nodes, c, k, list }: { nodes: Node[]; c: Theme; k: string; list?: 'ul' | 'ol' }) {
  const out: ReactNode[] = [];
  let run: Node[] = [];
  let li = 0;
  const flush = () => {
    const text = run.map(textOf).join('');
    if (text.trim() || run.some((n) => typeof n !== 'string' && n.tag === 'br')) {
      out.push(
        <Text key={`${k}-t${out.length}`} selectable style={{ color: c.text, fontSize: 15, lineHeight: 22 }}>
          {renderInline(trimRun(run), c, `${k}-t${out.length}`)}
        </Text>,
      );
    }
    run = [];
  };
  nodes.forEach((n, i) => {
    if (typeof n === 'string' || !isBlock(n)) {
      if (typeof n === 'string' || !DROP.has(n.tag)) run.push(n);
      return;
    }
    flush();
    const nk = `${k}-${i}`;
    if (n.tag === 'table') out.push(<Table key={nk} node={n} c={c} k={nk} />);
    else if (n.tag === 'hr') out.push(<View key={nk} style={{ height: 0.5, backgroundColor: c.separator, marginVertical: Spacing.two }} />);
    else if (n.tag === 'ul' || n.tag === 'ol') out.push(<Blocks key={nk} nodes={n.children} c={c} k={nk} list={n.tag} />);
    else if (n.tag === 'li') {
      li += 1;
      out.push(
        <View key={nk} style={{ flexDirection: 'row', gap: 6, paddingLeft: 4 }}>
          <Text style={{ color: c.textSecondary, fontSize: 15, lineHeight: 22 }}>{list === 'ol' ? `${li}.` : '•'}</Text>
          <View style={{ flex: 1 }}>
            <Blocks nodes={n.children} c={c} k={nk} />
          </View>
        </View>,
      );
    } else if (HEADING[n.tag]) {
      out.push(
        <Text key={nk} selectable style={{ color: c.text, fontSize: HEADING[n.tag], fontWeight: '700', lineHeight: HEADING[n.tag] + 6 }}>
          {renderInline(n.children, c, nk)}
        </Text>,
      );
    } else if (n.tag === 'blockquote') {
      out.push(
        <View key={nk} style={{ borderLeftWidth: 3, borderLeftColor: c.separator, paddingLeft: Spacing.two }}>
          <Blocks nodes={n.children} c={c} k={nk} />
        </View>,
      );
    } else out.push(<Blocks key={nk} nodes={n.children} c={c} k={nk} />);
  });
  flush();
  if (!out.length) return null;
  return <View style={{ gap: Spacing.two }}>{out}</View>;
}

function trimRun(run: Node[]): Node[] {
  const copy = [...run];
  while (copy.length && typeof copy[0] === 'string' && !copy[0].trim()) copy.shift();
  while (copy.length && typeof copy[copy.length - 1] === 'string' && !(copy[copy.length - 1] as string).trim()) copy.pop();
  if (typeof copy[0] === 'string') copy[0] = copy[0].replace(/^\s+/, '');
  return copy;
}

// neptun sends html soup, tables and all. no webview, just turn it into native views
export function HtmlView({ html }: { html: string }) {
  const c = useTheme();
  const source = /<[a-z][\s\S]*>/i.test(html) ? html : html.replace(/\n/g, '<br>');
  return <Blocks nodes={parseHtml(source)} c={c} k="h" />;
}