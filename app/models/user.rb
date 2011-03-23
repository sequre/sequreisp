# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

class User < ActiveRecord::Base
  acts_as_authentic do |c|
    c.logged_in_timeout = Configuration.first.logged_in_timeout.minutes rescue 10.minutes# default is 10.minutes
  end
  acts_as_audited :except => [
    :persistence_token,
    :single_access_token,
    :crypted_password,
    :password_salt,
    :perishable_token,
    :login_count,
    :failed_login_count,
    :last_request_at,
    :current_login_at,
    :last_login_at,
    :current_login_ip,
    :last_login_ip
  ]
  
  # aegis role
  has_role
  validates_role

  validates_presence_of :name, :email, :role_name
  
  def self.roles_for_select
    [
    [I18n.t("selects.user.role_name.admin"), "admin"],
    [I18n.t("selects.user.role_name.technical"),"technical"],
    [I18n.t("selects.user.role_name.technical_readonly"),"technical_readonly"],
    [I18n.t("selects.user.role_name.administrative"),"administrative"],
    [I18n.t("selects.user.role_name.administrative_readonly"),"administrative_readonly"]
    ]  
  end
end
