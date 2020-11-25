#!/bin/bash


export REST_HOST=$1
export user=$2
export pwd=$3


basic_auth()

    {
        set -x   #Comment here to remove pringting the cmds 
        printf "\n\n\n=====================\nBasic RESTConf Authentication\n=====================\n\n\n"
        curl -k -i -c cookie.txt -H "accept: application/json" -X GET https://$REST_HOST/restconf/data/v1/cisco-customer:customer --user $user:$pwd
        printf "\n\n"
        curl -k -i -b cookie.txt -H "accept: application/json" -X GET https://$REST_HOST/restconf/data/v1/cisco-customer:customer
        printf "\n\n"

    }

spring_auth ()

    {
        set -x
        printf "\n\n\n=====================\nSpring security check\n=====================\n\n\n" 
        printf "\n\n"
        curl -k -i -c cookie.txt -H "Content-type: application/x-www-form-urlencoded" -X POST https://$REST_HOST/restconf/j_spring_security_check -d "j_username=$user&j_password=$pwd" 
        printf "\n\n\n\n=====Cookie is =======\n\n\n"
        cat cookie.txt
        printf "\n\n"
        
    }

get_api()

    {
            #curl -k -i -b cookie.txt -H "accept: application/json" -X GET https://$REST_HOST/restconf/data/v1/cisco-customer:customer
            #printf "\n\n"
            #curl -k -i -b cookie.txt -H "accept: application/json" -X GET "https://$REST_HOST/restconf/data/v1/cisco-customer:customer"
            printf "\n\n"
            curl -k -i -b cookie.txt -H "accept: application/json" -X GET "https://$REST_HOST/restconf/data/v1/cisco-rtm:alarm?perceived-severity=major&.startIndex=0&.maxCount=1"
            printf "\n\n"
    }
        
clean()
    {
        printf "\n\n\n==========\nCleaning....\n==========\n\n"
        #cat cookie.txt
        rm cookie.txt
    }



#basic_auth REST_HOST pwd
spring_auth REST_HOST pwd
get_api REST_HOST pwd

clean
