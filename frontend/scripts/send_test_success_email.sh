#!/bin/bash
SMTP_SERVER=$1
SMTP_PORT=$2
SMTP_USERNAME=$3
SMTP_PASSWORD=$4
EMAILS=$5
TAG=$6
BRANCH_NAME=$7
COMMIT_AUTHOR=$8
SONARQUBE_URL_SET=${9}
NPM_REPORT_URL_SET=${10}
AUTOMATION_TEST_URL_SET=${11}
COMMIT_MESSAGE=${12}

ENGINEER_NAME=$(echo "$COMMIT_AUTHOR" | sed 's/ <.*//')
SONARQUBE_URL=http://sonarqube.enum.africa/dashboard?id=your-frontend-project
NPM_REPORT_URL=https://your-cdn-url/your-frontend-project/npm-reports/latest-report.html
AUTOMATION_TEST_URL=https://your-cdn-url/your-frontend-project/automation-tests-result/report.html
COMMIT_MESSAGE=$(echo "$COMMIT_MESSAGE" | sed 's/\\(/(/g; s/\\)/)/g; s/\\#/#/g')

IFS=',' read -r -a email_array <<< "${EMAILS}"
for email in "${email_array[@]}"
do
  cat << EOF > /tmp/email.html
From: builds@yourdomain.com
To: $email
Subject: Test Success
Content-Type: text/html
MIME-Version: 1.0

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Success</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 5px; padding: 20px; margin-bottom: 20px;">
        <h1 style="color: #155724; margin-top: 0;">Fantastic! Successful Test</h1>
        <p style="margin-bottom: 10px;">Congratulations, Your recent test in your-frontend-project was successful.</p>
    </div>
    
    <div style="background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 5px; padding: 20px; margin-bottom: 20px;">
        <h2 style="margin-top: 0;">Test Details</h2>
        <p><strong>ENGINEER:</strong> ${ENGINEER_NAME}</p>
        <p><strong>BRANCH:</strong> ${BRANCH_NAME}</p>
        <p><strong>TAG:</strong> ${TAG}</p>
        <p><strong>COMMIT MESSAGE:</strong> ${COMMIT_MESSAGE}</p>
    </div>

    <div style="background-color: #e9ecef; border: 1px solid #ced4da; border-radius: 5px; padding: 20px;">
        <h2 style="margin-top: 0;">Reports</h2>
        <p>Click on the links below to view your reports:</p>
        <ul style="padding-left: 20px;">
EOF

  if [ "$SONARQUBE_URL_SET" = "true" ]; then
    echo "<li><a href=\"$SONARQUBE_URL\" style=\"color: #007bff; text-decoration: none;\">SonarQube Report</a></li>" >> /tmp/email.html
  fi
  if [ "$NPM_REPORT_URL_SET" = "true" ]; then
    echo "<li><a href=\"$NPM_REPORT_URL\" style=\"color: #007bff; text-decoration: none;\">NPM Build Report</a></li>" >> /tmp/email.html
  fi
  if [ "$AUTOMATION_TEST_URL_SET" = "true" ]; then
    echo "<li><a href=\"$AUTOMATION_TEST_URL\" style=\"color: #007bff; text-decoration: none;\">Automation Test Report</a></li>" >> /tmp/email.html
  fi

  cat << EOF >> /tmp/email.html
        </ul>
    </div>

    <div style="margin-top: 20px; padding-top: 20px; border-top: 1px solid #ced4da;">
        <p style="margin-bottom: 5px;">Regards,</p>
        <p style="margin-top: 0;"><strong>The Cloud Team</strong></p>
    </div>
</body>
</html>
EOF

  curl --ssl-reqd \
    --url "smtps://${SMTP_SERVER}:${SMTP_PORT}" \
    --mail-from "builds@yourdomain.com" \
    --mail-rcpt "$email" \
    --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
    --upload-file /tmp/email.html
done
