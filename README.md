# Ruby on Rails applications on Azure
This repository is an attempt to describe how a Ruby to MySQL application may be migrated to Azure using containers.
It builds upon the Azure DevOps starter for Ruby, whose source code can be found by creating a Ruby DevOps starter project and then pulling the source code.
The DevOps Starter project can be found in the Azure portal:
![DevOps Starter page one](/images/devops-starter-one.png)
![DevOps Starter page two](/images/devops-starter-two.png)
![DevOps Starter page three](/images/devops-starter-three.png)

## MySQL on Azure
A number of samples using Ruby and MySQL deploy the MySQL server in a container. There is, however, a first class Azure service **Azure Database for MySQL**. This is a managed database service and so this should be the first choice for platform-based (PaaS) solutions.
This descibes using this approach and how to configure the Ruby container to access a database in Azure Database for MySQL.

## Initial Dockerfile
The initial Dockerfile for the Ruby DevOps starter is really basic, but works fine for a Ruby on Rails application:

```
FROM ruby:2.3
RUN apt-get update && apt-get install -y \ 
  build-essential \ 
  nodejs

RUN mkdir -p /app 
WORKDIR /app

COPY Gemfile Gemfile.lock ./ 
RUN gem install bundler && bundle install --jobs 20 --retry 5

COPY . ./

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```
This copies application code in a directory "app" and then runs rails server on port 3000.
