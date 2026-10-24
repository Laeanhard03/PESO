import 'package:flutter/material.dart';

import '../Reusable_Designs/reusable_ui.dart';

class JobKonekTutorial extends StatefulWidget {
  const JobKonekTutorial({super.key, required this.onExploreJobs});

  final VoidCallback onExploreJobs;

  @override
  State<JobKonekTutorial> createState() => _JobKonekTutorialState();
}

class _JobKonekTutorialState extends State<JobKonekTutorial> {
  int _stepIndex = 0;

  static const _steps = <({
    String title,
    String summary,
    IconData icon,
    List<String> actions,
    String tip,
  })>[
    (
      title: 'Create your account',
      summary: 'Start with a verified account so your profile and application progress belong to you.',
      icon: Icons.person_add_alt_1_rounded,
      actions: <String>[
        'Choose Create an account and enter your real name and contact details.',
        'Use an email address you can access and complete email verification.',
        'Sign in after verification to open your jobseeker dashboard.',
      ],
      tip: 'Use your own details. Do not create duplicate accounts to get around an account issue.',
    ),
    (
      title: 'Complete your profile and documents',
      summary: 'Prepare the information PESO and employers need before applying.',
      icon: Icons.description_outlined,
      actions: <String>[
        'Complete your profile, including your barangay and contact information.',
        'Create or upload your resume, and check that your education, experience, and skills are accurate.',
        'Open NSRP Form 1, follow the required-field markers, and save your completed form.',
      ],
      tip: 'Green labels identify form fields. A red asterisk (*) marks a required answer; use N/A only where the form says it is acceptable.',
    ),
    (
      title: 'Find a suitable opportunity',
      summary: 'Search the published vacancies and review each listing before you start an application.',
      icon: Icons.work_outline_rounded,
      actions: <String>[
        'Search by role or employer, then narrow the list using the available category filters.',
        'Review the job description, qualifications, location, schedule, and application instructions.',
        'Check categories such as Walk-in, Local Recruitment Activity, SEAP, and GIP when relevant.',
      ],
      tip: 'A matching or compatibility score is only guidance. It does not guarantee eligibility, referral, interview, or hiring.',
    ),
    (
      title: 'Apply and track your progress',
      summary: 'Submit accurate information and return to your dashboard to follow the application.',
      icon: Icons.task_alt_rounded,
      actions: <String>[
        'Open a vacancy and answer its screening questions truthfully.',
        'Review your documents and application details before submitting.',
        'Check your application dashboard for the current status and any next steps.',
      ],
      tip: 'If a listing is walk-in or has a separate employer process, follow the instructions shown on that listing.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < PesoTokens.breakpointCompact;
    final step = _steps[_stepIndex];

    return Container(
      key: const Key('jobkonek-how-it-works'),
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        vertical: compact ? PesoTokens.spacing2XL : PesoTokens.spacing4XL,
        horizontal: compact ? PesoTokens.spacingMD : PesoTokens.spacing2XL,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How JobKonek Works',
                textAlign: TextAlign.center,
                style: PesoTokens.headlineLarge,
              ),
              const SizedBox(height: PesoTokens.spacingSM),
              Text(
                'Follow this interactive tutorial one step at a time. Use Next to continue or jump to a step below.',
                textAlign: TextAlign.center,
                style: PesoTokens.bodyLarge.copyWith(color: PesoTokens.textMuted),
              ),
              const SizedBox(height: PesoTokens.spacingXL),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  key: const Key('jobkonek-tutorial-progress'),
                  value: (_stepIndex + 1) / _steps.length,
                  minHeight: 6,
                  backgroundColor: PesoTokens.brandGreenPale,
                  valueColor: const AlwaysStoppedAnimation<Color>(PesoTokens.brandGreen),
                ),
              ),
              const SizedBox(height: PesoTokens.spacingSM),
              Text(
                'STEP ${_stepIndex + 1} OF ${_steps.length}',
                textAlign: TextAlign.center,
                style: PesoTokens.labelMedium.copyWith(
                  color: PesoTokens.brandGreenDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: PesoTokens.spacingMD),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: PesoTokens.spacingSM,
                runSpacing: PesoTokens.spacingSM,
                children: [
                  for (var index = 0; index < _steps.length; index++)
                    ChoiceChip(
                      key: ValueKey<String>('jobkonek-tutorial-step-$index'),
                      label: Text('${index + 1}. ${_steps[index].title}'),
                      selected: _stepIndex == index,
                      selectedColor: PesoTokens.brandGreenPale,
                      onSelected: (_) => setState(() => _stepIndex = index),
                    ),
                ],
              ),
              const SizedBox(height: PesoTokens.spacingLG),
              Container(
                key: ValueKey<String>('jobkonek-tutorial-content-$_stepIndex'),
                padding: EdgeInsets.all(compact ? PesoTokens.spacingLG : PesoTokens.spacing2XL),
                decoration: BoxDecoration(
                  color: PesoTokens.surfaceNeutral,
                  borderRadius: BorderRadius.circular(PesoTokens.radiusContainer),
                  border: Border.all(color: PesoTokens.brandGreenLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: PesoTokens.brandGreenPale,
                            borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
                          ),
                          child: Icon(step.icon, color: PesoTokens.brandGreenDark, size: 26),
                        ),
                        const SizedBox(width: PesoTokens.spacingMD),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(step.title, style: PesoTokens.headlineSmall),
                              const SizedBox(height: PesoTokens.spacingSM),
                              Text(
                                step.summary,
                                style: PesoTokens.bodyMedium.copyWith(
                                  color: PesoTokens.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PesoTokens.spacingXL),
                    for (var index = 0; index < step.actions.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: PesoTokens.spacingMD),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: PesoTokens.brandGreenPale,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: PesoTokens.labelMedium.copyWith(
                                  color: PesoTokens.brandGreenDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: PesoTokens.spacingMD),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  step.actions[index],
                                  style: PesoTokens.bodyMedium.copyWith(
                                    color: PesoTokens.textPrimary,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: PesoTokens.spacingSM),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(PesoTokens.spacingMD),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(PesoTokens.radiusMD),
                      ),
                      child: Text(
                        'TIP  ${step.tip}',
                        style: PesoTokens.bodySmall.copyWith(
                          color: PesoTokens.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PesoTokens.spacingLG),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: PesoTokens.spacingSM,
                children: [
                  OutlinedButton.icon(
                    onPressed: _stepIndex == 0
                        ? null
                        : () => setState(() => _stepIndex--),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                  ),

                  FilledButton.icon(
                    onPressed: () {
                      if (_stepIndex < _steps.length - 1) {
                        setState(() => _stepIndex++);
                      } else {
                        widget.onExploreJobs();
                      }
                    },
                    icon: Icon(
                      _stepIndex == _steps.length - 1
                          ? Icons.work_outline_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      _stepIndex == _steps.length - 1
                          ? 'Finish & explore jobs'
                          : 'Next step',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: PesoTokens.brandGreenDark,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
