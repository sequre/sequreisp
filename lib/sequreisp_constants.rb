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
BASE_SCRIPTS="#{BASE}/scripts"
TC_FILE_PREFIX="#{BASE_SCRIPTS}/tc_"
IP_FILE_PREFIX="#{BASE_SCRIPTS}/ip_"
PROVIDER_UP_FILE_PREFIX= "#{BASE_SCRIPTS}/provider_up_"
PROVIDER_DOWN_FILE_PREFIX= "#{BASE_SCRIPTS}/provider_down_"
IP_RU_FILE="#{BASE_SCRIPTS}/ip_ru"
IP_RO_FILE="#{BASE_SCRIPTS}/ip_ro"
IP_RO_STATIC_FILE="#{BASE_SCRIPTS}/ip_ro_static"
IPTABLES_FILE="#{BASE_SCRIPTS}/iptables"
IPTABLES_PRE_FILE="#{BASE}/etc/iptables_pre.sh"
IPTABLES_POST_FILE="#{BASE}/etc/iptables_post.sh"
SEQUREISP_PRE_FILE="#{BASE}/etc/sequreisp_pre.sh"
SEQUREISP_POST_FILE="#{BASE}/etc/sequreisp_post.sh"
BOOT_FILE="#{BASE_SCRIPTS}/boot.sh"
BOOT_LOG="#{BOOT_FILE}.log"
CHECK_LINKS_FILE="#{BASE_SCRIPTS}/check_links.sh"
CHECK_LINKS_LOG="#{CHECK_LINKS_FILE}.log"
