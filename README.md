# Setup

In Gemfile:
```
gem 'devise-two-factor'
gem 'rqrcode'
```

In terminal:
```
rails g devise_two_factor User OTP_KEY
```

A couple of lines are added to the User model. Include `:two_factor_backupable`, too.

It also adds a few lines to the top of /config/initializers/devise.rb.
Make sure to add a line for the backupable, too.

```
config.warden do |manager|
  manager.default_strategies(:scope => :user).unshift :two_factor_authenticatable
  manager.default_strategies(:scope => :user).unshift :two_factor_backupable
end
```

Add a migration for backupable. Since in postgres, can use the `array:
true`. If were in MySQL would need to do something else.

```
add_column :users, :otp_backup_codes, :string, array: true.
```
