require 'mysql2'

begin
	# Initialize connection variables.
	host = String('jjtestmysql.mysql.database.azure.com')
	database = String('test')
    username = String('sqladmin@jjtestmysql')
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