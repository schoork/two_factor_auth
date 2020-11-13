class User < ApplicationRecord
  devise :two_factor_authenticatable, :two_factor_backupable,
         :otp_secret_encryption_key => ENV["TWOFACTOR_OTP_KEY"]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :registerable,
         :recoverable, :rememberable, :validatable

  def otp_qr_code
    issuer = "TwoFactor"
    label = "#{issuer}:#{email}"
    qrcode = RQRCode::QRCode.new(otp_provisioning_uri(label, issuer: issuer))
    qrcode.as_svg(module_size: 4)
  end
end
