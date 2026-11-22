import { useEventListener } from 'expo';
import { Image } from 'expo-image';
import { useVideoPlayer, VideoView, type VideoPlayer } from 'expo-video';
import { useRef } from 'react';
import { View } from 'react-native';
import Animated, { Easing, useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';

const SOURCE = require('../../assets/videos/NHNK-2FA-Tutorial.mov');
const BEZEL = require('../../assets/images/phone-bezel.png');

// measured off the 2242x4585 png, a bit past the hole so the corners tuck under the frame
const ASPECT = 2242 / 4585;
const SCREEN = { left: 108 / 2242, top: 96 / 4585, width: 2026 / 2242, height: 4392 / 4585, radius: 0.12 };
const FADE = 0.8;

function setup(p: VideoPlayer) {
  p.loop = false;
  p.muted = true;
  p.audioMixingMode = 'mixWithOthers';
  p.timeUpdateEventInterval = 0.1;
}

// muted loop inside the iphone frame. two players on the same file so the end crossfades into the start instead of snapping
export function TutorialVideo({ height }: { height: number }) {
  const a = useVideoPlayer(SOURCE, (p) => {
    setup(p);
    p.play();
  });
  const b = useVideoPlayer(SOURCE, setup);
  const top = useSharedValue(0);
  const active = useRef<'a' | 'b'>('a');

  const handoff = (next: 'a' | 'b') => {
    if (active.current === next) return;
    active.current = next;
    const to = next === 'a' ? a : b;
    to.replay();
    to.play();
    top.set(withTiming(next === 'b' ? 1 : 0, { duration: FADE * 1000, easing: Easing.inOut(Easing.quad) }));
  };
  const nearEnd = (p: VideoPlayer, t: number) => p.duration > FADE * 2 && t >= p.duration - FADE;

  useEventListener(a, 'timeUpdate', ({ currentTime }) => {
    if (active.current === 'a' && nearEnd(a, currentTime)) handoff('b');
  });
  useEventListener(b, 'timeUpdate', ({ currentTime }) => {
    if (active.current === 'b' && nearEnd(b, currentTime)) handoff('a');
  });
  // missed the window somehow, still never sit on a frozen last frame
  useEventListener(a, 'playToEnd', () => handoff('b'));
  useEventListener(b, 'playToEnd', () => handoff('a'));

  const topStyle = useAnimatedStyle(() => ({ opacity: top.get() }));
  const width = height * ASPECT;
  const screenW = width * SCREEN.width;
  const view = (player: VideoPlayer) => (
    <VideoView
      player={player}
      style={{ flex: 1 }}
      contentFit="cover"
      nativeControls={false}
      allowsPictureInPicture={false}
      fullscreenOptions={{ enable: false }}
      allowsVideoFrameAnalysis={false}
      playsInline
    />
  );

  return (
    <View style={{ width, height }}>
      <View
        style={{
          position: 'absolute',
          left: width * SCREEN.left,
          top: height * SCREEN.top,
          width: screenW,
          height: height * SCREEN.height,
          borderRadius: screenW * SCREEN.radius,
          overflow: 'hidden',
          backgroundColor: '#000',
        }}>
        <View style={{ position: 'absolute', inset: 0 }}>{view(a)}</View>
        <Animated.View style={[{ position: 'absolute', inset: 0 }, topStyle]}>{view(b)}</Animated.View>
      </View>
      <Image source={BEZEL} style={{ position: 'absolute', inset: 0 }} contentFit="contain" pointerEvents="none" />
    </View>
  );
}