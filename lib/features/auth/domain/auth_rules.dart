/// Règles de saisie alignées sur le backend (`schemas/auth.py`, config OTP).
const otpCodeLength = 6;

/// Délai avant de pouvoir redemander un code : le serveur refuse (429) tout
/// nouvel envoi dans la minute qui suit le précédent.
const otpResendSeconds = 60;

/// Durée de validité d'un code (`OTP_CODE_EXPIRES_MINUTES`).
const otpValidityMinutes = 5;

const minFullNameLength = 6;
const minPasswordLength = 4;

/// Canal d'envoi forcé en SMS (par défaut le serveur choisit WhatsApp puis SMS).
const otpChannelSms = 'sms';
