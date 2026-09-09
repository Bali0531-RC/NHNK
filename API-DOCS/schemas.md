# Confirmed response shapes

Field paths and types, captured from live responses. **Values were never recorded**:
they are a named student's grades, finances and personal data.

Observed on one institution, one account. `null` below means null *on that account*,
which usually means "this institution does not populate it" rather than "this field is
always empty". Anything consuming these must tolerate null.

---

## Message/GetUnreadedMessagesCount

    data.count    int
    notification  []

One integer. Replaces counting a 200-record message list by hand.

**Used by** `MailRequest.getUnreadCountFast()`, called from the background worker.

---

## dashboard/creditprogress

    data.completedCredit                          int
    data.requiredCredit                           int
    data.completedRequiredSubjectCredit           int
    data.sumRequiredSubjectCredit                 null
    data.completedRequiredOptionalSubjectCredit   int
    data.sumRequiredOptionalSubjectCredit         null
    data.completedOptionalSubjectCredit           null
    data.sumOptionalSubjectCredit                 null
    data.completedCurriculumCount                 int
    data.allCurriculumCount                       int
    data.hasCompletedCourseRequirements           bool
    notification                                  []

`advancement/creditprogress` returns an identical shape. The dashboard card and the
full progress page use one each.

**Only `completedCredit` and `requiredCredit` are dependable.** Four of the breakdown
totals were null on the account we probed, and Neptun's own web UI renders them as
"-", which is the precedent NHNK follows.

**Used by** `ProgressRequest.getRequiredCredits()`, which reads `requiredCredit` only.

---

## Message/GetReceivedMessages

    data.receivedMessages[].messageId
    data.receivedMessages[].senderUserId
    data.receivedMessages[].isCurrentUserMessageCreator
    data.receivedMessages[].senderName
    data.receivedMessages[].isSystemMessage
    data.receivedMessages[].subject
    data.receivedMessages[].lastPostDate
    data.receivedMessages[].unreadedPostCount
    data.receivedMessages[].hasAttachment
    data.receivedMessages[].taskId
    data.receivedMessages[].taskName
    data.receivedMessages[].taskDeadlineType
    data.receivedMessages[].uiDisplayState
    data.messagePrintFormType   str
    data.isCommunicationEnabled bool
    notification                []

Query: `?firstRow=<n>&lastRow=<n>&filterType=0`.

Two things worth knowing:

- **There is no total row count anywhere in the response.** The only way to learn how
  many messages exist is to fetch them, which is why NHNK still pulls the list in the
  foreground where pagination needs a total.
- **`lastRow` is an index, not a length.** `firstRow=0&lastRow=1` returned two
  messages.

---

## Dashboard/GetUpcomingEvents

    data.gridData[].courseCode    str
    data.gridData[].subjectId     str, 36 (guid)
    data.gridData[].courseId      str, 36 (guid)
    data.gridData[].termId        str, 36 (guid)
    data.gridData[].eventId       str, 36 (guid)
    data.gridData[].startDate     str, 19  "YYYY-MM-DDTHH:MM:SS"
    data.gridData[].endDate       str, 19
    data.gridData[].name          str
    data.gridData[].type          int
    data.gridData[].link          null
    data.gridData[].online        bool
    data.gridData[].uiDisplayState.type
    data.gridData[].uiDisplayState.reasons
    data.additionalData.additionalUpComingEventsCount  int
    data.additionalData.meetingsCountToBeAccepted      int
    notification                  []

**Not a replacement for `CalendarRequest.fetchUpcoming()`.** This returns three events
plus a count of the rest, because it backs a dashboard card. NHNK's Upcoming page
covers an eight week window, so the existing multi-week fetch stays.

---

## Advancement/GetStudentCurriculumTemplates

    data[].advancementRowId                          str, 36 (guid)
    data[].curriculumTemplateId                      int
    data[].curriculumTemplateName                    str
    data[].curriculumTemplateCode                    str
    data[].actualCreditsCompletedNumber              int
    data[].creditsRequiredNumber                     null
    data[].actualRequiredSubjectGroupCompletedNumber int
    data[].requiredSubjectGroupNumber                null
    data[].actualRequiredSubjectCompletedNumber      int
    data[].requiredSubjectNumber                     int

Curriculum data does exist on the modern API, contradicting an earlier conclusion in
this project. Note `creditsRequiredNumber` was null here while
`creditprogress.requiredCredit` was populated, so prefer the latter.

Not yet used by NHNK.

---

## Curriculum/GetOptionalSubjectsSummary

    data.isSuccessful     bool
    data.isOverachieved   bool
    data.completedCredit  null
    data.requiredCredit   null
    notification          []

Both numbers were null on the probed account, so there is nothing to build on yet.
Worth re-probing on another institution before relying on it.

---

## Empty on the probed account

These returned HTTP 200 with an empty payload, so their shape is **unknown**. They may
be perfectly useful on an account that has the relevant data; we simply cannot say.

    Dashboard/GetAverages              data.dashboardAverageItems[]  empty
                                       data.studentTrainingTermDataId, termId, termName  all null
    RegistrySheet/GetStudentAverages   data[]  empty
    OfferedGrades/GetOfferedGrades     data[]  empty

Do not implement against these without probing an account that has grades, offered
grades and a computed average.
