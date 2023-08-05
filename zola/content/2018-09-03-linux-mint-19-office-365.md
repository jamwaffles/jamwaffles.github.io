+++
layout = "post"
title = "Office 365 in Linux Mint 19: Calendar, Email, Notifications"
date = "2018-09-03 11:42:00"
categories = "linux"
+++

# Office 365 mail, calendar and notifications in Linux Mint 19

1. Install Evolution with the Exchange addons

```bash
apt install evolution evolution-ews evolution-plugins
```

1. Add your Exchange account by going to **Settings** -> **Online Accounts** and selecting
   **Microsoft Exchange**.
1. You may need to use an _App Password_ in Office 365 if required by your domain admin. If so, open
   up your account settings at <https://portal.office.com/account/#security> and navigate to
   **Security & Privacy** and click **Create and manage app passwords**. Click **Create**, give the
   password a descriptive name. Once created, copy the generated password to your clipboard.
1. Add your details like the following:

   ![Office365 login details](/assets/images/mint-o365-details.png)

   Enter your email address and password as usual. Under **Custom**, make sure **Username** is your
   email address, and **Server** is `outlook.office365.com`.

1. Hit `Connect`.

If all went well, your email account should already be present in Evolution when you open it, and
events should show up in Calendar. You'll also get calendar notifications for upcoming events.
