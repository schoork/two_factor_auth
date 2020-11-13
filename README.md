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

[GoRails
video](https://gorails.com/episodes/two-factor-auth-with-devise)

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

Add a new controller to run the sessions.
app/controllers/users/sessions_controller.rb:

```
class Users::SessionsController < Devise::SessionsController
  def pre_otp
    user = User.find_by pre_otp_params
    @two_factor_enabled = user && user.otp_required_for_login

    respond_to do |format|
      format.js
    end
  end

  private

  def pre_otp_params
    params.require(:user).permit(:email)
  end
end
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
Authenticator app. It also displays the QR code and backup codes for
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

Add the following to app/controllers/application_controller.rb. I'm not
sure the first parameter is necessary since we don't allow people to
just sign up.

```
before_action :configure_permitted_parameters, if: :devise_controller?

  protected

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:name])
      devise_parameter_sanitizer.permit(:account_update, keys: [:name])
      devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])
    end
```

You'll also need to fix the login view for two forms. Both forms will be
contained in app/views/devise/sessions/new.html.erb.
1. Just the email, will check to see if the user requires two factor
   auth for login.
2. Display the password field (and two factor field if necessary).

The first form will look like this. The path, method, remote, and html
attributes have been changed and a submit button has been added.
```
<%= form_for(resource, as: resource_name, url: users_pre_otp_path, method: :post, remote: true, html: {id: 'step-1'}) do |f| %>
  <div class="field">
    <%= f.label :email %><br />
    <%= f.email_field :email, autofocus: true, autocomplete: "email" %>
  </div>

  <div class="form-group">
    <%= f.submit "Next" %>
  </div>
<% end %>
```

The second part of the form won't change much, but there are a couple of
updates.

Add some html parameters to the form and a new two factor code field.

```
<%= form_for(resource, as: resource_name, url: session_path(resource_name), html: {class: 'd-none', id: 'step-2'}) do |f| %>
...
  <%= f.text_field :otp_attempt, label: '2FA Code', class: 'd-none', id:
'step-2-otp' %>
...
<% end %>
```

Last, but not least, add js file for the pre_otp action.
app/views/devise/sessions/pre_otp.js.erb:
```
var stepOne = $("#step-1")
var stepTwo = $("#step-2")

stepOne.addClass('d-none')
stepTwo.removeClass('d-none')

var email = stepOne.find("#user_email").val()
stepTwo.find("#user_email").val(email)
stepTwo.find("#user_password").focus()

<% if @two_factor_enabled %>
  $("#step-2-otp").removeClass('d-none')
<% end %>
```

# Usage

This app creates a way for users to enable and disable two-factor
authorization. Would need to change a bit if wanted to force for all
users. Some thoughts on this:
1. Allow users their first sign in without, or give them a backup code
   in email.
2. Instead of disable button, will need a button to reset backup codes.
3. This seems a little bit overkill. Give users the ability to do it,
   but don't force them.
