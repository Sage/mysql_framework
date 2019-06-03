FROM ruby:2.5

# Create application directory and set it as the WORKDIR.
ENV APP_HOME /mysql_framework
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

COPY . $APP_HOME
