FROM ruby:2.3

ENV sqlpassword=test

RUN apt-get update && apt-get install -y \ 
  build-essential \ 
  nodejs \
  build-essential \
  default-libmysqlclient-dev \
  nano

RUN gem install mysql2

RUN mkdir -p /app 
WORKDIR /app

COPY Gemfile Gemfile.lock ./ 
RUN gem install bundler && bundle install --jobs 20 --retry 5

COPY . ./

EXPOSE 3000
CMD /bin/sh
#CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]