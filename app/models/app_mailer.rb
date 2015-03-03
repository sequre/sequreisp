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

class AppMailer < SequreMailer

  def check_links_email
    set_language
    recipients Configuration.notification_email.split(",")
    set_from
    subject "[wispro] " + I18n.t('app_mailer.check_links_email.subject')
    sent_on Time.now
    content_type "text/html"
    #body {:user => user, :url => "http://example.com/login"}
  end

  def check_physical_links_email
    set_language
    recipients Configuration.notification_email.split(",")
    set_from
    subject "[wispro] " + I18n.t('app_mailer.check_physical_links_email.subject')
    sent_on Time.now
    content_type "text/html"
    #body {:user => user, :url => "http://example.com/login"}
  end

  private

  def set_from
    if Rails.env.development?
      from "Wispro <noreply@wispro.com.ar"
    else
      from "Wispro <noreply>"
    end
  end

end
