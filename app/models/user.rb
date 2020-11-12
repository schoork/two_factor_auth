class User < ApplicationRecord
  devise :two_factor_authenticatable, :two_factor_backupable,
         :otp_secret_encryption_key => ENV['OTP_KEY']

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :registerable,
         :recoverable, :rememberable, :validatable
end
