import smtplib
from email.mime.image import MIMEImage
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

def send_mail_smtp(mail_from, mail_to, mail_subject, mail_message, mail_server="mail.rg-rus.ru"):
    msg = MIMEMultipart()
    msg['Subject'] = mail_subject
    msg['From'] = mail_from
    msg['To'] = ', '.join(mail_to)
    msg.attach(MIMEText(mail_message, 'plain'))
    s = smtplib.SMTP(mail_server)
    s.sendmail(mail_from, mail_to, msg.as_string())
    s.quit()
