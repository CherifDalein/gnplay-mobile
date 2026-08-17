import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/design_system/gn_design_system.dart';
import '../../domain/register_request.dart';
import '../providers/auth_controller.dart';
import '../providers/register_controller.dart';

enum _RegisterStep { account, otp }

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _accountFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  var _step = _RegisterStep.account;
  bool _obscurePassword = true;

  static const _countryIso2 = 'GN';
  static const _countryLabel = 'Guinée (GNF)';

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phoneNumber => _phoneController.text.trim();

  Future<void> _continueToOtp() async {
    FocusScope.of(context).unfocus();
    if (!_accountFormKey.currentState!.validate()) {
      return;
    }

    final ok = await ref
        .read(registerControllerProvider.notifier)
        .requestOtp(phoneNumber: _phoneNumber);

    if (!mounted || !ok) {
      return;
    }

    setState(() => _step = _RegisterStep.otp);
  }

  Future<void> _resendOtp() async {
    FocusScope.of(context).unfocus();
    await ref
        .read(registerControllerProvider.notifier)
        .requestOtp(phoneNumber: _phoneNumber);
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();
    if (!_otpFormKey.currentState!.validate()) {
      return;
    }

    final registerController = ref.read(registerControllerProvider.notifier);
    final otpOk = await registerController.verifyOtp(
      phoneNumber: _phoneNumber,
      code: _codeController.text.trim(),
    );
    if (!mounted || !otpOk) {
      return;
    }

    final request = RegisterRequest(
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneNumber,
      countryIso2: _countryIso2,
      password: _passwordController.text,
    );
    final user = await registerController.register(request);
    if (!mounted || user == null) {
      return;
    }

    ref.read(postAuthRedirectProvider.notifier).state = '/become-creator';
    final token = await ref
        .read(authControllerProvider.notifier)
        .loginAfterRegistration(
          phoneNumber: _phoneNumber,
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (token == null) {
      ref.read(postAuthRedirectProvider.notifier).state = null;
      context.go('/login');
      return;
    }

    context.go(user.isCreator ? '/home' : '/become-creator');
  }

  @override
  Widget build(BuildContext context) {
    final registerState = ref.watch(registerControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isLoading = registerState.isLoading || authState.isLoading;
    final errorMessage = registerState.whenOrNull(
      error: (error, _) => error is ApiException
          ? error.message
          : 'Une erreur inattendue est survenue.',
    );

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: GnAppBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 54,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _BackButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (_step == _RegisterStep.otp) {
                                    setState(() {
                                      _step = _RegisterStep.account;
                                    });
                                    return;
                                  }
                                  context.go('/login');
                                },
                        ),
                      ),
                      const SizedBox(height: 22),
                      _ProgressBars(step: _step),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _step == _RegisterStep.account
                            ? _AccountStep(
                                key: const ValueKey('account'),
                                formKey: _accountFormKey,
                                fullNameController: _fullNameController,
                                phoneController: _phoneController,
                                passwordController: _passwordController,
                                countryLabel: _countryLabel,
                                obscurePassword: _obscurePassword,
                                onTogglePassword: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                isLoading: isLoading,
                                onContinue: _continueToOtp,
                              )
                            : _OtpStep(
                                key: const ValueKey('otp'),
                                formKey: _otpFormKey,
                                codeController: _codeController,
                                phoneNumber: _phoneNumber,
                                isLoading: isLoading,
                                onSubmit: _createAccount,
                                onResend: _resendOtp,
                              ),
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 14),
                        _ErrorText(message: errorMessage),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.phoneController,
    required this.passwordController,
    required this.countryLabel,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.isLoading,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final String countryLabel;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final bool isLoading;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Créer votre compte',
            style: AppTextStyles.displayMd.copyWith(
              color: AppColors.text1,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Étape 1 sur 2 · vos informations',
            style: AppTextStyles.label.copyWith(
              color: AppColors.text3,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 24),
          GnTextField(
            controller: fullNameController,
            label: 'Nom complet',
            placeholder: 'Mariama Diallo',
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().length < 6) {
                return 'Le nom doit contenir au moins 6 caractères.';
              }
              return null;
            },
          ),
          const SizedBox(height: 13),
          _CountryField(value: countryLabel),
          const SizedBox(height: 13),
          GnTextField(
            controller: phoneController,
            label: 'Numéro de téléphone',
            placeholder: '+224 621 45 88 07',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().length < 9) {
                return 'Le numéro de téléphone est requis.';
              }
              return null;
            },
          ),
          const SizedBox(height: 13),
          GnTextField(
            controller: passwordController,
            label: 'Mot de passe',
            placeholder: '••••••••',
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!isLoading) {
                onContinue();
              }
            },
            suffixIcon: TextButton(
              onPressed: onTogglePassword,
              child: Text(
                obscurePassword ? 'Voir' : 'Masquer',
                style: AppTextStyles.micro.copyWith(color: AppColors.accent500),
              ),
            ),
            validator: (value) {
              if (value == null || value.length < 4) {
                return 'Le mot de passe doit contenir au moins 4 caractères.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          GnButton(
            label: 'Continuer',
            isLoading: isLoading,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    super.key,
    required this.formKey,
    required this.codeController,
    required this.phoneNumber,
    required this.isLoading,
    required this.onSubmit,
    required this.onResend,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final String phoneNumber;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Vérification',
            style: AppTextStyles.displayMd.copyWith(
              color: AppColors.text1,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: AppTextStyles.label.copyWith(
                color: AppColors.text3,
                fontWeight: FontWeight.w400,
              ),
              children: [
                const TextSpan(text: 'Code à 6 chiffres envoyé au '),
                TextSpan(
                  text: phoneNumber,
                  style: const TextStyle(color: AppColors.text1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _OtpCodeField(controller: codeController),
          const SizedBox(height: 18),
          TextButton(
            onPressed: isLoading ? null : onResend,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.text3,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                children: const [
                  TextSpan(text: 'Renvoyer le code dans '),
                  TextSpan(
                    text: '00:45',
                    style: TextStyle(
                      color: AppColors.accent500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          GnButton(
            label: 'Vérifier',
            isLoading: isLoading,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              style: AppTextStyles.caption.copyWith(color: AppColors.text3),
              children: const [
                TextSpan(text: 'Votre compte est créé en tant que '),
                TextSpan(
                  text: 'spectateur',
                  style: TextStyle(color: AppColors.text2),
                ),
                TextSpan(text: '. Vous pourrez passer créateur juste après.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCodeField extends StatefulWidget {
  const _OtpCodeField({required this.controller});

  final TextEditingController controller;

  @override
  State<_OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<_OtpCodeField> {
  final _focusNode = FocusNode();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleChanged);
    _focusNode.addListener(_handleChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChanged);
    _focusNode.removeListener(_handleChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) {
      if (_errorText != null && widget.controller.text.length == 6) {
        _errorText = null;
      }
      setState(() {});
    }
  }

  void _setError(String? message) {
    if (_errorText == message) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _errorText = message;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _focusNode.requestFocus,
              child: Row(
                children: List.generate(6, (index) {
                  final hasValue = index < code.length;
                  final isActive = _focusNode.hasFocus && index == code.length;

                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 5 ? 0 : 9),
                      child: AspectRatio(
                        aspectRatio: 1 / 1.15,
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(
                              color: isActive
                                  ? AppColors.accent500
                                  : AppColors.border1,
                            ),
                          ),
                          child: Text(
                            hasValue ? code[index] : '',
                            style: AppTextStyles.title.copyWith(
                              color: AppColors.text1,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      _setError('Entrez le code à 6 chiffres.');
                      return '';
                    }
                    _setError(null);
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
        if (_errorText != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            _errorText!,
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _CountryField extends StatelessWidget {
  const _CountryField({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return GnCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      radius: AppRadii.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pays',
            style: AppTextStyles.micro.copyWith(color: AppColors.text3),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.body.copyWith(color: AppColors.text1),
                ),
              ),
              Text(
                '⌄',
                style: AppTextStyles.heading.copyWith(color: AppColors.text3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({required this.step});

  final _RegisterStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _ProgressBar(isActive: true)),
        const SizedBox(width: 6),
        Expanded(child: _ProgressBar(isActive: step == _RegisterStep.otp)),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: isActive ? AppColors.accent500 : AppColors.border1,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retour',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: const SizedBox(
          width: 36,
          height: 36,
          child: CustomPaint(painter: _BackArrowPainter()),
        ),
      ),
    );
  }
}

class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.text2
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.78, size.height * 0.5)
      ..lineTo(size.width * 0.22, size.height * 0.5)
      ..moveTo(size.width * 0.43, size.height * 0.25)
      ..lineTo(size.width * 0.22, size.height * 0.5)
      ..lineTo(size.width * 0.43, size.height * 0.75);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: AppTextStyles.caption.copyWith(color: AppColors.danger),
    );
  }
}
