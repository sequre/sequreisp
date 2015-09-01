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

#PPP_PEER_DIR="/etc/ppp/peer"
BASE=SequreispConfig::CONFIG["base_dir"]
PPP_DIR=SequreispConfig::CONFIG["ppp_dir"]
DHCPD_DIR=SequreispConfig::CONFIG["dhcpd_dir"]
PINGABLE_SERVERS=SequreispConfig::CONFIG["pingable_servers"]
IFB_UP=SequreispConfig::CONFIG["ifb_up"]
IFB_DOWN=SequreispConfig::CONFIG["ifb_down"]
IFB_INGRESS=SequreispConfig::CONFIG["ifb_ingress"]
DEPLOY_DIR=SequreispConfig::CONFIG["deploy_dir"]

# paths
BASE_SCRIPTS="#{BASE}/scripts"
BASE_SCRIPTS_TMP="#{BASE_SCRIPTS}/tmp"
BOOT_FILE="boot.sh"
TC_FILE_PREFIX="tc_"
IP_RU_FILE="ip_ru"
IPTABLES_FILE="iptables"
IPTABLES_PRE_FILE="#{BASE}/etc/iptables_pre.sh"
IPTABLES_POST_FILE="#{BASE}/etc/iptables_post.sh"
SEQUREISP_PRE_FILE="#{BASE}/etc/sequreisp_pre.sh"
SEQUREISP_POST_FILE="#{BASE}/etc/sequreisp_post.sh"

# logs
COMMAND_LOG ="#{DEPLOY_DIR}/log/command.log"
HUMANIZED_COMMAND_LOG ="#{DEPLOY_DIR}/log/command_human.log"
APPLICATION_LOG = "#{DEPLOY_DIR}/log/application.log"
SOFT_NAME = "Wispro"

# postfix
PATH_POSTFIX = Rails.env.production? ? "/etc/postfix/main.cf" : "/tmp/main.cf"
PATH_SASL_PASSWD = Rails.env.production? ? "/etc/postfix/sasl_passwd" : "/tmp/sasl_passwd"
