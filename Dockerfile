FROM ubuntu:12.04
MAINTAINER lruete@wispro.co

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -q -y git-core build-essential autoconf bison wget subversion imagemagick librrd-dev librrd4 libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev libmysqlclient-dev vim gawk libsqlite3-dev sqlite3 libgmp-dev libtool libgmp-dev curl libxslt1.1 libxslt1-dev libgtk-3-0 libgtkmm-3.0-1 libnotify4 \
	&& adduser --disabled-password --gecos "" wispro \
	&& su - wispro -c '\curl -sSL https://get.rvm.io | bash -s stable' \
	&& su - wispro -c 'rvm install 1.8.7' \
	&& su - wispro -c 'rvm install rubygems 1.3.7 --force' \
  && su - wispro -c 'rvm use 1.8.7@wispro --create && gem install bundler --no-ri --no-rdoc -v 1.15.1' \
	&& mkdir -p /app \
  && chown -R wispro.wispro /app

EXPOSE 3000


# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
CMD "su - wispro -c 'echo $(whoami) && echo $PATH && echo $(pwd) && cd /app && bundle exec rails server -b 0.0.0.0'"

