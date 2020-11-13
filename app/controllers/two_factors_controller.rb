class TwoFactorsController < ApplicationController

  def create
    @codes = current_user.generate_otp_backup_codes!
    current_user.update(
      otp_secret: User.generate_otp_secret,
      otp_required_for_login: true,
    )
  end

  def destroy
    current_user.update(
      otp_required_for_login: false
    )
  end

end
