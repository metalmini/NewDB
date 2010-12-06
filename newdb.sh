#! /bin/bash
#set -x

#
# Check for all needed parameters
# We first have to know what to do
if [ -z $1 ]
then
        echo "Usage:"
        echo "newdb.sh action databasename [username [ip]]"
        exit 1
fi

#
# A databasename is needed
#
if [ -z $2 ]
then
        echo "Usage:"
        echo "newdb.sh action databasename [username [ip]]"
        exit 1
fi

ACTION=$1
DBNAME=$2

#
# if the third option is missing, make it the same as the second option
#
if [ -z $3 ]
then
        USERNAME=$2
else
        USERNAME=$3
fi

#
# Let's define a couple of things
#
MYSQLPASSWORD=`cat /etc/mysql.passwd`
CHECKUSER=`mysql mysql --password=\`cat /etc/mysql.passwd\` -e "select User from user where User='$USERNAME' LIMIT 1"|sed s/User//`
CHECKDB=`mysql mysql --password=\`cat /etc/mysql.passwd\` -e "select Db from db where Db='$DBNAME' LIMIT 1"|sed s/Db//`
MYSQL=/usr/bin/mysql
MYSQLADMIN=/usr/bin/mysqladmin
NETACCESS='localhost'
PASSLENGTH="8"
MATRIX="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

if [ -f /usr/local/scripts/newdb.conf ]
then
        . /usr/local/scripts/newdb.conf
fi

#
# The lenght of the username may not exceed 16 chars
#
UNAMELENGTH=`echo $USERNAME | wc -c`
if [  $UNAMELENGTH -gt 17 -a $ACTION == 'create' ] # 17bytes is the max when creating
then
  echo "Username $USERNAME is too long. 16 Characters maximum."
  exit 1
fi

#
# the fourth optional option is a space separated list
# of ips/hostnames/networks between quotes
#
if [ -n "$4" ]
then
  NETACCESS="$NETACCESS $4"
fi


#
# Let's create some functions
#

# One for creating a database
createdb()
{

#
# Check if the user already exists
#
if [ -z $CHECKUSER ]
then
        echo "User is ok"
else
        echo "User " $USERNAME " already exists, choose another username"
        exit 1
fi

#
# Check if the database already exists
#
if [ -z $CHECKDB ]
then
        echo "Database is ok"
else
        echo "Database" $DBNAME" already exists, choose another name"
        exit 1
fi

#
# Generate a password for the user
#
while [ ${n:=1} -le $PASSLENGTH ]
do
        GENPASS="$GENPASS${MATRIX:$(($RANDOM%${#MATRIX})):1}"
        let n+=1
done

#
# Create the new database
#
$MYSQLADMIN --password=$MYSQLPASSWORD create $DBNAME

#
# Create the user in mysql
#
for host in $NETACCESS
do
  $MYSQL --password=$MYSQLPASSWORD -D mysql -e "insert into user (host,user, password) values ('$host','$USERNAME',PASSWORD('$GENPASS'))"
done

# we need a flush now, not sure why
$MYSQL --password=$MYSQLPASSWORD -D mysql -e "flush privileges;"

#
# Correct the permissions of the added user
#
for host in $NETACCESS
do
  $MYSQL --password=$MYSQLPASSWORD -D mysql -e "revoke all on *.* from $USERNAME@'$host';"
#  $MYSQL --password=$MYSQLPASSWORD -D mysql -e "insert into db (host, db, user, Select_priv, Insert_priv, Update_priv,Delete_priv, Create_priv, Drop_priv, Alter_priv, Index_priv, Create_tmp_table_priv, References_priv, Grant_priv ) values ('$host','$DBNAME','$USERNAME','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y','Y')"
  $MYSQL --password=$MYSQLPASSWORD -D mysql -e "GRANT ALL PRIVILEGES ON $DBNAME.* to '$USERNAME'@'$host' IDENTIFIED BY '$GENPASS'"
done

#
# Maak de instellingen aktief
#
$MYSQL --password=$MYSQLPASSWORD -D mysql -e "flush privileges;"

#
# Tell root the database properties
#
echo ""
echo " --- start ---"
echo "New database " $DBNAME "has been created"
echo "Username          = "$USERNAME
echo "Password          = "$GENPASS
echo "Databasename      = "$DBNAME
echo " ---- done ---- "
}



#
# And a function to remove a database (no backup, we've got Donald)
#
deletedb()
{

# check if the user really exists

if [ -z $CHECKUSER ]
        then
        echo "User $USERNAME does not exist!"
        exit 1
else
        echo "User $USERNAME will be deleted"
fi

# Check if the database really exists

if [ -z $CHECKDB ]
        then
        echo "Database $DBNAME does not exist!"
        exit 1
else
        echo "Database $DBNAME will be deleted"
fi

# First drop the database
$MYSQLADMIN --force --password=$MYSQLPASSWORD drop  $DBNAME

# Then remove the database from mysql
$MYSQL --password=$MYSQLPASSWORD -D mysql -e "delete from db where Db='$DBNAME';"

# And finally: remove the user from mysql
$MYSQL --password=$MYSQLPASSWORD -D mysql -e "delete from user where User='$USERNAME';"

#
# Maak de instellingen aktief
#
$MYSQL --password=$MYSQLPASSWORD -D mysql -e "flush privileges;"


echo "The database has been deleted"
}


#
# Time for some action
#
case $ACTION in
        create) createdb ;;

        delete) deletedb ;;

        drop) deletedb ;;

        *) echo "Unknown action" ;;
esac

