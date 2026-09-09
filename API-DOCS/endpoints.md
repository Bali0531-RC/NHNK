# Neptun modern web API, observed routes

Captured 2026-09-09 by driving the real web client with an interceptor. See
[discovery.md](discovery.md) for the method.
Host neptun-ws01.uni-pannon.hu (Pannon), Neptun build 2026.2.13, one student account.

Method, path and status only. No response bodies, no query strings: the bodies hold
grades, messages and personal data.

**180 routes.** NHNK calls 16 of them as of 2.0.0. Paths omit the `/hallgato/api/`
prefix. Status shown only when it was not 200; `-> 0` means the request was
cancelled by navigation, not an error.

---

## Already used by NHNK

    POST Account/Authenticate
    POST Account/GetNewTokens
    GET  Calendar/GetCalendarEvents
    GET  Calendar/GetCourseDetails            (not seen in this crawl)
    GET  Calendar/GetLinksForCalendarExport
    GET  Calendar/GetStudentTrainings
    GET  Message/GetReceivedMessages          (not seen; messages page not visited)
    GET  Periods/GetPeriods
    GET  Periods/GetTerms
    GET  SubjectCourse/GetSubjectDetails
    GET  TakenSubjects
    GET  TakenSubjects/Terms
    GET  Tasks/GetTaskDetail                  (not seen in this crawl)
    GET  Transactions/GetStudentPreviousTransactions
    GET  Message/GetUnreadedMessagesCount     added in 2.0.0
    GET  dashboard/creditprogress             added in 2.0.0

## Session and profile

    GET  UserInfo
    GET  Permissions
    GET  ExtendedMenuPermissions
    GET  Profiles/Favourites
    GET  MyTrainings
    GET  UserProfile/IsPasswordModificationAllowed
    GET  ContextUserProfile/GetOnboardingProfileData
    GET  ContextUserProfile/GetColumnOrder
    GET  ContextUserProfile/GetColumnOrderType
    GET  ContextUserProfile/GetFilter
    GET  ContextUserProfile/GetCalendarSelectedView
    GET  ContextUserProfile/GetCalendarSelectedTypes
    GET  ContextUserProfile/GetSubjectSigninSelectedView
    GET  ContextUserProfile/GetSubjectSigninWarningModalsStates
    POST ContextUserProfile/SaveFilter
    POST ContextUserProfile/SaveCalendarSelectedView
    POST ContextUserProfile/SaveCalendarSelectedTypes
    POST ContextUserProfile/SaveOnboardingProfileData

## Dashboard

    GET  dashboard/actualterm
    GET  dashboard/creditprogress
    GET  Dashboard/GetAverages
    GET  Dashboard/GetAverageTypesDescription
    GET  Dashboard/GetUpcomingEvents
    GET  Dashboard/GetTasks
    GET  Dashboard/GetNumberOfTasksByType
    GET  Dashboard/GetNews
    GET  Dashboard/GetImpositions
    GET  Dashboard/GetExamsDashboardData
    GET  Dashboard/GetRemainingExamCount
    GET  Dashboard/GetCompletedAndUncompletedExamsCount
    GET  Dashboard/GetNumberOfIndexLineEntry
    GET  Dashboard/GetListOfTopItemsFromIndexLineEntry
    GET  Tasks/GetDashboardTasksData
    GET  Tasks/GetDashboardExpiringTasksData

## Progress, curriculum, registry sheet

    GET  advancement/creditprogress
    GET  Advancement/GetTermAveragesByTraining
    GET  Advancement/GetStudentCurriculumTemplates
    GET  Curriculum/GetOptionalSubjectsSummary
    GET  SubjectApplication/Curriculum
    GET  study/registrysheet/actualterm
    GET  RegistrySheet/GetGeneralTrainingData
    GET  RegistrySheet/GetStudentAverages
    GET  RegistrySheet/GetStudentTakenSubjectsByTerm
    GET  RegistrySheet/GetStudentTrainingTermData
    GET  RegistrySheet/GetAdditionalStudentTrainingTermData
    GET  RegistrySheet/GetCertificateResults
    GET  RegistrySheet/GetCertificatePartialResults
    GET  RegistrySheet/GetCurrentProfessions
    GET  RegistrySheet/GetCurrentSpecializations
    GET  RegistrySheet/GetOfficialRecords
    GET  RegistrySheet/GetTermIndependentAccreditedSubjects

## Subjects and courses

    GET  SubjectCourse/GetSubjectCourseList
    GET  SubjectCourse/GetTerms
    GET  RegisteredCourses/GetRegisteredCourses
    GET  RegisteredCourses/GetTerms
    GET  OfferedGrades/GetOfferedGrades
    GET  SubjectEquivalence/GetInnerSubjectsEquivalenceData
    GET  SubjectRelatedRequestForm/GetSubjectRelatedFillableRequestForms
    GET  General/GetSubjectInformationInSchedulePlanner
    GET  General/GetDictionaryItem
    GET  NoteSearch/GetNotesList

### Subject registration (form pages, read endpoints only)
    GET  SubjectApplication/Terms
    GET  SubjectApplication/SubjectTypes
    GET  SubjectApplication/SubjectGroup
    GET  SubjectApplication/SchedulableSubjects
    GET  SubjectApplication/GetSubjectsCourses
    GET  SubjectApplication/SystemParameters

## Exams

    GET  Exam/GetTerms
    GET  ExamOverview/GetAvailableExamsCount
    GET  ExamOverview/GetDashboardExamEntries
    GET  ExamOverview/GetDashboardActualTermExamEntries
    GET  ExamOverview/GetDashboardExamEntriesInActualTerm
    GET  ExamRegistration/GetExamsList
    GET  ExamRegisteredExams/GetRegisteredExamsList
    GET  ExamRemainingExams/GetRemainingRegisteredExamsList
    GET  ExamResults/GetExamResultsList
    GET  ExamResults/GetTermsForGetExamResultsList
    GET  FinalExams/GetFinalExamResults
    GET  FinalExams/GetFuturePeriods
    GET  FinalExams/GetNumberOfActivePeriods
    GET  FinalExams/GetActiveApplicationsOfStudent
    GET  FinalExams/GetPreviousApplicationsOfStudent

## Finance

    GET  FinancialItem/GetItemsToBePayed
    GET  FinancialItem/GetItemsToBePayedAdditionalData
    GET  FinancialDataDashboard/GetCollectiveInvoices
    GET  FinancialDataDashboard/GetDashboardElementsVisibility
    GET  FinancialDataDashboard/GetDashboardImpostionBlockLeft
    GET  FinancialBonuses/GetStudentFinancialBonuses
    GET  FinancialBonuses/GetTermsForStudentFinancialBonusesTermFilter
    GET  FinancialOptions/GetStudentLoan2Data
    GET  Invoices/GetInvoicesForStudent
    GET  ImpositionStatement/GetImpositionStatements
    GET  Scholarship/GetScholarshipPayments
    GET  Scholarship/GetScholarshipAvailablePaymentTerms
    GET  StudentLoan/GetStudentLoan
    GET  Transactions/GetStudentPreviousTransactionsFilters
    GET  Transactions/GetStudentPreviousTransactionTypesFilter

## Calendar

    GET  Calendar/GetNewAllAppointmentInvitations
    GET  OnlineOccasion/GetNextOccasion
    GET  OnlineOccasion/GetAllOccasionNumber
    GET  OnlineOccasion/GetOnlineAppointmentsCount
    GET  OnlineOccasion/GetCourseNumber
    GET  OnlineOccasion/GetExamNumber
    GET  OnlineOccasion/GetFinalExamNumber
    GET  OnlineOccasion/GetConsultationNumber
    GET  OnlineOccasion/GetTaskNumber

## Messages

    GET  Message/GetUnreadedMessagesCount

## E-learning material

    GET  ematerial/main-types
    GET  EMaterial/GetSubjectEMaterials
    GET  EMaterial/GetCourseEMaterials
    GET  EMaterial/GetGeneralEMaterials
    GET  EMaterial/GetOtherVirtualSpaceEMaterials
    GET  EMaterial/GetEmaterialsToDashboard
    GET  EMaterial/GetResultsCardView
    GET  EMaterial/GetStudentTerms
    GET  EMaterial/GetStudentTermsForResultsCardView
    GET  EMaterial/GetStudentHasEmailAddress
    GET  EMaterial/GetStudenthasEmailAddress      (yes, two spellings exist)

## Thesis, practice, consultation

    GET  Consultation/GetConsultations
    GET  ThesisApplication/GetStudentValidThesisIntervals
    GET  CommonThesis/GetThesisApplicationsAndThesisesByStudent
    GET  PublishedTheses/GetPublishedTheses
    GET  Practice/GetPracticesList
    GET  Practice/GetPracticeListPermissions
    GET  Practice/GetDualContratList
    GET  ExternalPractice/GetSignedInIntervalList
    GET  ExternalPractice/GetPreviousIntervals
    GET  ExternalPractice/GetDashboardIntervalData

## Administration

    GET  administration/semiannualregistration/semesters
    GET  RequestForm/GetStudentRequestFormTemplates
    GET  RequestForm/GetSubmittedRequestForms
    GET  RequestForm/GetNumberOfRequestForms
    GET  RequestJudgement/GetReceivedRequestForms
    GET  RequestJudgement/GetNumberOfRequestFormsForJudgement
    GET  RequestJudgement/GetAvailabilityOfGroupJudgement
    GET  Questionnaires/GetQuestionnaires
    GET  Questionnaires/GetFinishedQuestionnaires
    GET  Questionnaires/GetUnipollReports
    GET  Questionnaires/IsUnipollUrlEmpty
    GET  Questionnaires/IsUnipollReportUrlEmpty
    GET  ReclassificationRequest/GetReclassificationTerms
    GET  StudentCard/GetStudentAddress
    GET  StudentCard/GetStudentCardPreviousClaims
    GET  StudentCard/StudentCardClaimProcess
    GET  GeneralForm/GetStudentGeneralForms
    GET  ModuleSelection/GetSelectedModules
    GET  ModuleSelection/GetPeriodsCount
    GET  ModuleSelection/GetActivePeriodsCount
    GET  Specialization/GetSpecializationListData
    GET  Dormitory/GetDormitoryDashboardPeriodsData
    GET  Erasmus/ErasmusIsActive
    GET  Erasmus/GetErasmusPeriodsForDropDown
    GET  Sciencer/isAuthAvailable

## Information

    GET  Periods/GetPeriods
    GET  Periods/GetTerms
    GET  FIR/GetStudentFIRData
    GET  Publication/GetPublications
    GET  Publication/InsertPublicationAllowed

## Communal spaces

    GET  MeetStreetMain/GetPublicNews
    GET  MeetStreetMain/GetGlobalForums
    GET  MeetStreetMain/GetAllVirtualSpaceNews
    GET  MeetStreetMain/GetAllVirtualSpaceForums
    GET  MeetStreetMain/GetAllVirtualSpaceDocuments
    GET  MeetStreetMain/GetFavouriteVirtualSpaces
    GET  MeetStreetMain/CanCreateOwnVirtualSpace
    GET  MeetStreetMain/GetMyVirtualSpacesActivities    500, Neptun's own error

---

## What this means for NHNK

### Done in 2.0.0

**`Message/GetUnreadedMessagesCount`.** api_coms.dart used to say "The modern API
exposes no count endpoint, so the list itself is counted" and downloaded 200 message
records. The background worker now asks for the single integer instead, which is where
the cost mattered: that check runs periodically on mobile data. The foreground still
fetches the list, because pagination needs a total and no endpoint reports one.

**`dashboard/creditprogress`.** Supplies `requiredCredit`, the number the statistics
page used to make the student pick from chips. The manual value still wins if set, and
the chips remain for institutions without the endpoint.

### Checked and deliberately not changed

**`Dashboard/GetUpcomingEvents`** is not a replacement for
`CalendarRequest.fetchUpcoming()`. It returns three events plus a count, because it
backs a dashboard card; the Upcoming page covers eight weeks.

**The foreground unread count** still pulls the message list. Dropping it would mean
replacing the pagination guard, which is driven by a total that only the list can
provide. Judged not worth the risk for the gain.

### Still open

**Curriculum data exists**, contradicting the earlier write-off:
`Curriculum/GetOptionalSubjectsSummary`, `Advancement/GetStudentCurriculumTemplates`
and `SubjectApplication/Curriculum`. The first returned nulls on the probed account,
so it needs a second sample before anything is built on it.

**Averages from the server**, `RegistrySheet/GetStudentAverages` and
`Dashboard/GetAverages`, both empty on the probed account.

**Whole features the app does not have:** offered grades, exams end to end,
scholarships and payments due, questionnaires, e-learning material, thesis and
practice, student card, Erasmus. `OfferedGrades/GetOfferedGrades` is probably the one
students would notice most.

---

## Caveat
One institution, one Neptun build, one account. Nothing here is safe to assume
universal. Every use needs guarding, with the existing path kept as fallback for
legacy-API institutions and for null or missing fields, exactly as creditprogress
already showed with four null fields on this very account.
