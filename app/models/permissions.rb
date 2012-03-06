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

class Permissions < Aegis::Permissions
  role :admin, :default_permission => :allow
  role :administrative
  role :technical
  role :administrative_readonly
  role :technical_readonly

  resources :clients, :plans, :graphs do
    writing do
      allow :administrative, :technical
    end
    reading do
      allow :administrative, :technical, :administrative_readonly, :technical_readonly
    end
  end
  action :names_clients do
    allow :technical, :technical_readonly, :administrative, :administrative_readonly
  end

  resources :contracts do
    writing do
      allow :administrative, :technical
    end
    reading do
      allow :administrative, :technical, :administrative_readonly, :technical_readonly
    end
    action :instant_rate do
      allow :technical, :technical_readonly, :administrative, :administrative_readonly
    end
  end
  action :free_ips_contracts, :ips_contracts do
    allow :technical, :technical_readonly, :administrative, :administrative_readonly
  end

  resources :providers, :provider_groups, :interfaces do
    writing do
      allow :technical
    end
    reading do
      allow :technical, :technical_readonly
    end
    action :instant_rate do
      allow :technical, :technical_readonly, :administrative, :administrative_readonly
    end
  end

  resources :users do
  end

  resource :configuration do
    writing do
      allow :technical
    end
    reading do
      allow :technical
    end
    action :index do
      allow :technical, :technical_readonly
    end
    action :doreload do
      allow :technical, :administrative
    end
  end

  resource :backup do
  end

  resources :audits do
  end

  resource :dashboard do
    reading do
      allow :technical, :technical_readonly
    end
    action :cpu, :services, :load_average do
      allow :technical, :technical_readonly
    end
  end

end

