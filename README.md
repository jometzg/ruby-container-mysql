# Ruby on Rails applications on Azure
This repository describes how a Ruby to MySQL application may be migrated to Azure using docker containers.
It builds upon the Azure DevOps starter for Ruby, whose source code can be found by creating a Ruby DevOps starter project and then pulling the source code.
For a MySQL database, the Azure plaform service *Azure Database for MySQL" will be used.

## TL;DR
A Ruby on Rails application can be configured to work in a container to Azure Database for MySQL easily, but there are a number of steps to bear in mind:
1. The MySQL driver for Ruby is a different install to that of a MySQL Server
2. By default this is not included in the ruby base image
3. Azure Database for MySQL does not create a database on provisioning. This needs to be done afterwards
4. SSL/TLS configuration requires the container to contain a specific certificate to work.
5. Environment variables can be used to pass secrets e.g. database connection information into the container.
5. The firewall on the Azure Database for MySQL need to be updated to allow the container location to be whitelisted.
6. Docker image upload to Azure Container Registry (ACR)
7. Web App for Containers to use the above image
8. Use application settings in the web app to set secrets, which will then be container environment variables

## DevOps starter
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

## Dockerfile with a MySQL driver
```
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
#CMD /bin/sh
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```
In the above Dockerfile, the *default-libmysqlclient-dev* library is included and later the mysql driver installed via *gem install*.
Also notice, that for debugging purposes, the nano editor has been addded and also at the bottom of the Dockerfile, there is commented-out *CMD /bin/sh* - this will allow you to work inside the container interactively.

## Sample Ruby SQL code to validate the connection to MySQL
The original sample did not have any MySQL code, so some has been borrowed from [here](https://docs.microsoft.com/en-us/azure/mysql/connect-ruby), which will allow the configuration and connection to the Azure Database for MySQL to be validated. This uses the MySql2 library https://github.com/brianmario/mysql2

```
require 'mysql2'

begin
   # Initialize connection variables.
   host = String('your-server.mysql.database.azure.com')
   database = String('yourdatabase')
   username = String('youruser@yoursever')
   password = String(ENV["sqlpassword"])
   ssl_ca = String('/app/app/rubymysql/BaltimoreCyberTrustRoot.crt.pem')

	# Initialize connection object.
    client = Mysql2::Client.new(:host => host, 
                            :username => username, 
                            :database => database, 
                            :password => password, 
                            :sslca => ssl_ca)
    puts 'Successfully created connection to database.'

    # Drop previous table of same name if one exists
    client.query('DROP TABLE IF EXISTS inventory;')
    puts 'Finished dropping table (if existed).'

    # Drop previous table of same name if one exists.
    client.query('CREATE TABLE inventory (id serial PRIMARY KEY, name VARCHAR(50), quantity INTEGER);')
    puts 'Finished creating table.'

    # Insert some data into table.
    client.query("INSERT INTO inventory VALUES(1, 'banana', 150)")
    client.query("INSERT INTO inventory VALUES(2, 'orange', 154)")
    client.query("INSERT INTO inventory VALUES(3, 'apple', 100)")
    puts 'Inserted 3 rows of data.'

# Error handling
rescue Exception => e
    puts e.message

# Cleanup
ensure
    client.close if client
    puts 'Done.'
end
```
There are a number of things here that need calling-out in order to understand what is happening:
1. Azure Database for MySQL has a server name of the form *your-server.mysql.database.azure.com* where *your-server* is a name of the server as created in the Azure portal. This is a fully-qualified domain name (FQDN) and as such needs to be globally unique.
2. In the Azure portal, there is no opportunity to define a database separately from the server - which is different to Azure SQL Database. Nor is there a means later in the portal to do this AFAIK. So, you need to create a database at a later time after the server has been provisioned. One way to do this is to open a mysql session to the server and then create a database. There is some guidance [here](https://docs.microsoft.com/en-gb/azure/mysql/quickstart-create-mysql-server-database-using-azure-portal?WT.mc_id=Portal-Microsoft_Azure_Marketplace#connect-to-the-server-with-mysql-command-line-client) on how to do this in the Azure Cloud Shell.

![Create database in cloud shell](/images/mysql-cloud-shell2.png)

3. The database for the connection is the one created in the previous step.
4. Connections to the database should be under SSL/TLS. This appears to require that the code have access to a certificate PEM file that is discussed [here](https://docs.microsoft.com/en-us/azure/mysql/howto-configure-ssl) The certifate needs to be in a container and in a known path. The line:
```
ssl_ca = String('/app/app/rubymysql/BaltimoreCyberTrustRoot.crt.pem')
```
refers to the path *inside the container* that the PEM file can be found. This will then allow you to enable the *Enforce SSL connection* setting in for Azure Database for MySQL. This is shown highlighted below:
![Enforce SSL connection](/images/enforce-ssl.png)

Now running the sample SQL Ruby code will result in the following:
![SQL code run](/images/code-run.png)

5. Ideally, the database connection information should not be present in the code :-) So, this should be injected into the container at runtime.
```
ENV sqlpassword=test
```
And then the Ruby database connection code needs to reference that environment variable:
```
password = String(ENV["sqlpassword"])
```
For running the container locally:
```
docker run -it --env sqlpassword=actualpassword rubysample
```
If you then host the container in Azure Web App for Containers, application settings get injected into the container as environment variables. If the target host for the application is Azure web app for Containers, [here](https://docs.microsoft.com/en-us/azure/app-service/configure-custom-container?pivots=container-windows#configure-environment-variables) is some documentation on how environment variables and app service application settings work together. 

## Deployment to Azure Web App for Containers
As with most containers, deployment is a multi-step process:
1. Build the container image
2. Push the image to Azure Container Respository (ACR)
3. Using Web App for Containers, pull the image to the web app from the ACR instance.

### Build and push container image
```
docker build -t rubysample:100
docker tag rubysample:100 youracr.azurecr.io/rubysample:100
docker push youracr.azurecr.io/rubysample:100
```
### Create a web app
The simplest method is to do this in the Azure portal.
![Create web app one](/images/create-web-app-one.png)
![Create web app two](/images/create-web-app-two.png)

This will create a web app using the container. You can also drive configuration into a web app using Configuration, add application setting:

![Web app settings](/images/web-app-settings.png)

## Summary
Ruby database applications that use MySQL can be migrated to Azure easily with containers, Web App for Containers and Azure Database for MySQL.
