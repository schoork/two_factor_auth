# Postgres in Development

This is needed for the backup codes. SQLite doesn't handle arrays.
[This page](https://www.digitalocean.com/community/tutorials/how-to-use-postgresql-with-your-ruby-on-rails-application-on-macos)
explains how to setup a postgres DB on local machine.

Incidentally this will help with the ILIKE problem with searching.

## Installing Postgres

In the terminal run:
```
$ postgres -V
```

If you get something like `postgres (PostgreSQL) 10.9`, then skip to
running postgres.

If you get an error, run in the terminal. In the third line, replace
the 10 with the version installed.
```
$ brew install postgresql
$ postgres -V
$ echo 'export PATH="/usr/local/opt/postgresql@10/bin:$PATH"' >> ~/.bash_profile
$ source ~/.bash_profile
```

## Running Postgres

In the terminal run the following, replacing the 10 with the version
number of the postgres installation.
```
$ brew services start postgresql@10
```

## Database Configuration and Creation

Change the database configuration for default, development, and test. config/database.yml:
```
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  username: samwilliams
  password: <%= ENV['TWOFACTORAUTH_DATABASE_PASSWORD'] %>

development:
  <<: *default
  database: twofactorauth_development

# Warning: The database defined as "test" will be erased and
# re-generated from your development database when you run "rake".
# Do not set this db to the same as development or production.
test:
  <<: *default
  database: twofactorauth_test
```

In terminal:
```
$ echo 'export TWOFACTORAUTH_DATABASE_PASSWORD="PostgreSQL_Role_password"' >> ~/.bash_profile
$ source ~/.bash_profile
$ rails db:create
$ rails db:migrate
```

# Two Factor Installation

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

Another line that is added is `:otp_secret_encryption_key => ENV['OTP_KEY']`. To set the OTP_KEY, open rails console and create a key:

```
> SecureRandom.hex 16
```

Exit the console. Copy the value and input in the bash_profile by running:

```
$ echo 'export OTP_KEY=< KEY >' >> ~/.bash_profile
```

You can check this worked by opening the console again and running `>
ENV["OTP_KEY"]`. It should give you the key.

Make sure to source bash_profile in any and all terminal windows/tabs.

The installer also adds a few lines to the top of /config/initializers/devise.rb.
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

Run `rails db:migrate`.

# Setup

Override the normal sessions controller by changing the normal
`devise_for :users` in config/routes.rb.

```
devise_for users, controllers: {sessions: "users/sessions"}
```

Also in the routes file. `resource :two_factor` will give us a way for
users to turn on and off two factor authentication. 

```
devise_scope :user do
  scope :users, as: :users do
    post 'pre_otp', to: "users/sessions#pre_otp"
  end
end

resource :two_factor
```

Create app/controller/two_factors_controller.rb and add the following.

```
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
```

Since both create and destroy will be sent over AJAX, they can benefit
from some return partials. Add app/views/two_factors/create.js.erb and
app/views/two_factors/destroy.js.erb. Add the following line to both.

```
$("#two_factor").html("<%=j render partial: "two_factor" %>")
```

Then in the registration view (using for this temp app), display the
partial inside of a div with the same id. Placed below the form, it
looks like this.

```
<hr>

<h2>Two Factor Authentication</h2>

<div id="two_factor">
  <%= render "devise/registrations/two_factor" %>
</div>

</hr>
```

The partial will have buttons for enabling and disabling two factor
authentication, as long as directions for downloading the Google
Authenticator app. It also displays the qr code and backup codes for
users to write down.

app/views/devise/registrations/_two_factor.html.erb:

```
<% if current_user.otp_required_for_login %>
  <div><%= link_to "Disable", two_factor_path, method: :delete, remote: true %></div>

  <div class="row">
    <div class="col-8">
      <ol class="mt-5">
        <li>
          Install Google Authenticator:
          <%= link_to "Android", "https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2&hl=en", target: '_blank' %>
          or
          <%= link_to "iOS", "https://itunes.apple.com/us/app/google-authenticator/id388497605?mt=8", target: :blank %>
        </li>
        <li>In the app, select, "Set up account" or the Plus (+) sign.</li>
        <li>Choose "scan barcode".</li>
      </ol>
    </div>

    <div class="col-4 text-center">
      <%= current_user.otp_qr_code.html_safe %>
    </div>
  </div>

  <% if @codes %>
    <hr>

    <p><strong class="badge badge-danger">Important!</strong> Write these backups codes down in a safe place. They can be used once to login to your account if your 2FA device is unavailable. They will never be displayed again for security.</p>

    <% @codes.each do |code| %>
      <div><strong><%= code %></strong></div>
    <% end %>
  <% end %>
<% else %>
  <p>When you login, you will be required to enter a one-time code along to one of your devices.</p>
  <div><%= link_to "Enable", two_factor_path, method: :post, remote: true %></div>
<% end %>
```

Define a method in app/models/user.rb:

```
def otp_qr_code
  issuer = "TwoFactor"
  label = "#{issuer}:#{email}"
  qrcode = RQRCode::QRCode.new(otp_provisioning_uri(label, issuer: issuer))
  qrcode.as_svg(module_size: 4)
end
```


# Usage

In terms of switching everyone over, could set `:opt_required_for_login`
as default on new users and could do a callback or something if they
don't have it on the first time they login.


