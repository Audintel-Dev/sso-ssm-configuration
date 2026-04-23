# 📘 SSO-SSM User Manual

This document provides step-by-step instructions to set up **AWS SSO** along with **AWS Systems Manager (SSM)** using CLI commands on your local system.

It enables secure access to EC2 and RDS instances in the UAT and PROD accounts **via SSM**, eliminating the need for `.pem` key files or direct SSH access.

---

## 🔐 Access Method

We use **SSM-based access**, which means:

* No SSH keys (`.pem`) required
* No direct inbound access (no open ports like 22)
* Access is managed securely through AWS IAM and SSO
* Sessions are initiated using the AWS CLI

---

## 💡 Benefits

* Centralized authentication using AWS SSO
* Improved security (no key management)
* Auditable session logs via SSM
* Easy access to both EC2 and RDS environments

---

## ✅ Pre-requisites

Before proceeding, ensure the following requirements are met:

1. **GitHub Access**

   * You must have a GitHub account using your company email (`{name}@audintel.in`)
   * Your account should be added to the organization: **Audintel-Dev**

2. **AWS Access**

   * You must have access to the company’s AWS accounts
   * Appropriate **AWS SSO permission sets** should be assigned to you for:

     * UAT account
     * PROD account

---

### 💡 Note

If you do not have any of the above access, please contact your administrator or DevOps team before proceeding.

---

## 🚀 1. Clone the Repository

Open your terminal:

* **Windows** → PowerShell
* **Mac/Linux** → zsh / bash

---

## 📥 Clone the Repository

Run the following command:

```bash
git clone https://github.com/Audintel-Dev/sso-ssm-configuration.git
```

---

## 🔑 Authentication Details

You will be prompted for credentials:

* **Username**

  * Use your company email: `{name}@audintel.in`
    **OR**
  * Your GitHub username linked to this email

* **Password**

  * Use your **Personal Access Token (PAT)**
  * ⚠️ GitHub does **NOT** accept your regular account password for CLI authentication

---

## 🛠️ Create a Personal Access Token (PAT)

If you don’t already have a PAT, follow these steps:

1. Go to your **GitHub profile** (not the organization).
2. Navigate to:
   **Settings → Developer Settings → Personal Access Tokens**
3. Choose one:

   * **Fine-grained tokens** (recommended)
   * **Classic tokens**
4. Create a token:

   * Give it a meaningful name
   * Set appropriate permissions (repo access required)
   * (Optional) Set expiration as per policy
5. Copy and securely store the token

   * ⚠️ This acts as your password for Git operations

---

## ⚠️ Troubleshooting

* If authentication fails:

  * Ensure you are using the **correct username and PAT**
* If cloning still fails:

  * You likely **don’t have access to the repository**
  * Contact the **DevOps Team** to request access

---

## 📂 2. Navigate to Project Folder

After successfully cloning the repo on your system, do:

```bash
cd sso-ssm-configuration
```

### 👉 For Windows Users

* Go to `windows/` folder
* Run:

```powershell
install.ps1
```


## 🔐 PowerShell Execution Policy Setup

To allow running local PowerShell scripts (like `install.ps1`), set the execution policy:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

- After that open new terminal.

- Follow interactive prompts (keep pressing **Next**).

---

### 👉 For Mac/Linux Users

* Go to `mac-linux/` folder
* Run:

```bash
bash install.sh
```

---

## 🔐 3. Configure AWS SSO  (FOR UAT)

Run:

```bash
aws configure sso
```

### Enter the following details:

* **SSO session name**: `uat`
* **SSO start URL**:

  ```
  https://d-9f676488e3.awsapps.com/start/
  ```
* **SSO region**: `ap-south-1`
* **SSO registration scopes**: Press **Enter**

---

## 🌐 4. Browser Authentication

* A browser window will open
* Click **Allow Access**

📸 Reference:
![Browser Login](browser.png)

---

## ✅ 5. Authentication Response

After login, you will see confirmation:

📸 Reference:
![Auth Response](auth-res.png)

---

## 🏢 6. Select AWS Account

You will see two accounts:

### 🔹 Production Account

```
Raghavendra Sinha, raghu@audintel.com (471201224424)
```

### 🔹 UAT Account

```
Audintel@UAT, raghu@audintel.in (670307493739)
```

👉 Select based on your use case:

* **UAT setup → choose UAT account**
* **Prod setup → choose Production account**

**Here you should choose the UAT account.**

---

## 🔑 7. Select Permission Set

You may see options like:

```
uat-developers-access
ReadOnlyAccess
ViewOnlyAccess
uat-DBA-permissions

```

👉 Choose the permission set based on your access needs:

---

## ⚙️ 8. Final Configuration Inputs

* **Default client region**: `us-east-1`
* **CLI output format**: `json`
* **Profile name**: `uat`

---

## 🧪 9. Verify Configuration

```bash
aws sts get-caller-identity --profile uat
```
**Expected Output:**

```json
{
    "UserId": "AROAW3NOIC3UKPHXZRX54:sivaramakrishna.konka@audintel.in",
    "Account": "670307493739",
    "Arn": "arn:aws:sts::670307493739:assumed-role/AWSReservedSSO_CustomDevOpsPermissions_c8e8bb7ee530af45/sivaramakrishna.konka@audintel.in"
}
```
---

## 🔁 10. Repeat Steps to Configure AWS SSO (For PROD)

Repeat the same steps with these changes:

Run:

```bash
aws configure sso
```

### Enter the following details:

* **SSO session name**: `prod`
* **SSO start URL**:

  ```
  https://d-9f676488e3.awsapps.com/start/
  ```
* **SSO region**: `ap-south-1`
* **SSO registration scopes**: Press **Enter**

---

## 🌐 11. Browser Authentication

* A browser window will open
* Click **Allow Access**

📸 Reference:
![Browser Login](browser.png)

---

## ✅ 12. Authentication Response

After login, you will see confirmation:

📸 Reference:
![Auth Response](auth-res.png)

---

## 🏢 13. Select AWS Account

You will see two accounts:

### 🔹 Production Account

```
Raghavendra Sinha, raghu@audintel.com (471201224424)
```

### 🔹 UAT Account

```
Audintel@UAT, raghu@audintel.in (670307493739)
```

👉 Select based on your use case:

**Here you should choose the Production account.**

---

## 🔑 14. Select Permission Set

You may see options like:

```
prod-spring-developers-access
ReadOnlyAccess
ViewOnlyAccess
prod-DBA-permissions

```

👉 Choose the permission set based on your access needs:

---

## ⚙️ 15. Final Configuration Inputs

* **Default client region**: `us-east-1`
* **CLI output format**: `json`
* **Profile name**: `prod`

---

## 🧪 16. Verify Configuration

```bash
aws sts get-caller-identity --profile prod
```

---

* Select **Production account**:

  ```
  Raghavendra Sinha, raghu@audintel.com (471201224424)
  ```
* Use:

  * **SSO session name**: `prod`
  * **Profile name**: `prod`

---

## 🧪 17. Verify the Configuration

### 🔹 Check Production Profile

```bash
aws sts get-caller-identity --profile prod
```

**Expected Output:**

```json
{
    "UserId": "AROAW3NOIC3UKPHXZRX54:sivaramakrishna.konka@audintel.in",
    "Account": "471201224424",
    "Arn": "arn:aws:sts::471201224424:assumed-role/AWSReservedSSO_CustomDevOpsPermissions_c8e8bb7ee530af45/sivaramakrishna.konka@audintel.in"
}
```

---

## ✅ What This Means

* ✔️ SSO login is successful
* ✔️ AWS CLI is properly configured
* ✔️ You are assuming the correct IAM role
* ✔️ Ready to use SSM, S3, RDS, etc.

## 🎯 Final Outcome

You will have two profiles configured:

```bash
uat
prod
```
Use profiles like this 

```
aws s3 ls --profile uat
aws s3 ls --profile prod
```


---

## 🚀 Usage Commands

### 🔄 Reload Alias Configuration

Run the appropriate command based on your OS:

#### 🪟 Windows (PowerShell)

```powershell
. $PROFILE
```

#### 🍎 macOS (zsh)

```bash
source ~/.zshrc
```

#### 🐧 Linux (bash)

```bash
source ~/.bashrc
```

---

## ⚡ Available Shortcuts / Aliases

| Command  | Description                           |
| -------- | ------------------------------------- |
| `uat`    | Connect to Linux UAT servers          |
| `prod`   | Connect to Linux Production servers   |
| `dbuat`  | Open tunnels for UAT databases        |
| `dbprod` | Open tunnels for Production databases |
| `dbpc`   | Check if ports are actively listening |

---

## 💡 Notes
* If a command doesn’t work, try restarting the terminal.

---

# 🗄️ Database Connection Configuration

*(DBeaver / Sequel Ace)*

---

## 📌 Overview

This setup allows you to connect to multiple databases using **local port forwarding**.

* **Host:** `127.0.0.1` (for all connections)
* **Differentiation:** Done using **unique local ports**

---

## 🔧 Database Port Mapping

## 🗄️ Production Databases

```ini
[prod_databases]
audinteldb     = 3411
auspigroup     = 3412
chrobinsondb   = 3413
ffsdb          = 3414
idrivedb       = 3415
redwood        = 3416
shiphawk       = 3417
```

---

## 🧪 UAT Databases

```ini
[uat_databases]
uat-aud1-encrypted = 3307
uat-chr            = 3308
uat-ffs            = 3309
```
---

## 🔄 Customizing Ports

* By default, ports are predefined (as shown above)
* If a port is already in use on your local machine:

### 👉 Steps to change port

1. Navigate to your home directory
2. Locate the file:

   ```
   ~/.rds-map
   ```
3. Update the port number as needed

---

## 🌐 Connection Details

Use the following settings in **DBeaver** or **Sequel Ace**:

| Setting  | Value                   |
| -------- | ----------------------- |
| Host     | `127.0.0.1`             |
| Port     | As per mapping          |
| DB Name  | Based on your selection |
| User     | (your DB username)      |
| Password | (your DB password)      |

---

## ⚠️ Important Configuration (DBeaver)

In **DBeaver**, make sure to enable:

```id="dbeaver-setting"
allowPublicKeyRetrieval=true
```

👉 This is required for successful authentication in some MySQL setups.

---

## 💡 Notes

* Each database runs on a **different local port**
* All connections go through **localhost (127.0.0.1)**
* Port forwarding must be active before connecting
* Restart your DB client if changes are not reflected

---

## 🚀 Example

To connect to **`ffsdb` (prod)**:

* Host: `127.0.0.1`
* Port: `3414`

---
