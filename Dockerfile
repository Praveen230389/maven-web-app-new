# Tomcat का ऑफिशियल लाइटवेट जावा इमेज लें
FROM tomcat:9.0-jdk17-corretto

# मैवेन द्वारा बनाए गए WAR पैकेज को टॉमकैट के वेब-ऐप्स फोल्डर में कॉपी करें
COPY target/01-maven-web-app-3.0-RELEASE.war /usr/local/tomcat/webapps/ROOT.war

EXPOSE 8080
CMD ["catalina.sh", "run"]
