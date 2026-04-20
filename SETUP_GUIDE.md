# SETUP GUIDE — Build This in Your Salesforce Developer Org

## Step 1: Sign Up for Free Developer Org
- Go to: https://developer.salesforce.com/signup
- Fill in the form, verify email
- Log in to your new org

## Step 2: Create Custom Object — AI_Interaction_Log__c

Go to: Setup → Object Manager → Create → Custom Object

| Field | Value |
|-------|-------|
| Label | AI Interaction Log |
| Plural Label | AI Interaction Logs |
| Object Name | AI_Interaction_Log |
| Record Name | Log Number (Auto Number: LOG-{0000}) |

### Add Custom Fields:

| Field Label | API Name | Type | Length |
|-------------|----------|------|--------|
| Action | Action__c | Text | 255 |
| Record Id | Record_Id__c | Text | 18 |
| Request Payload | Request_Payload__c | Long Text Area | 131072 |
| Response Payload | Response_Payload__c | Long Text Area | 131072 |
| Status | Status__c | Text | 50 |
| Timestamp | Timestamp__c | Date/Time | - |
| User | User__c | Lookup(User) | - |
| User Name | User_Name__c | Text | 255 |
| Session Id | Session_Id__c | Text | 255 |


## Step 3: Create Platform Event — AI_Case_Event__e

Go to: Setup → Platform Events → New Platform Event

| Field | Value |
|-------|-------|
| Label | AI Case Event |
| Plural Label | AI Case Events |
| Object Name | AI_Case_Event |

### Add Custom Fields:

| Field Label | API Name | Type | Length |
|-------------|----------|------|--------|
| Case Id | Case_Id__c | Text | 18 |
| Action | Action__c | Text | 255 |
| Priority | Priority__c | Text | 50 |


## Step 4: Create Platform Event — AI_Log_Event__e

Go to: Setup → Platform Events → New Platform Event

| Field | Value |
|-------|-------|
| Label | AI Log Event |
| Plural Label | AI Log Events |
| Object Name | AI_Log_Event |

### Add Custom Fields:

| Field Label | API Name | Type | Length |
|-------------|----------|------|--------|
| Action | Action__c | Text | 255 |
| Record Id | Record_Id__c | Text | 18 |
| Payload | Payload__c | Long Text Area | 131072 |
| Status | Status__c | Text | 50 |
| User Id | User_Id__c | Text | 18 |


## Step 5: Create Custom Metadata Type — AI_Config__mdt

Go to: Setup → Custom Metadata Types → New Custom Metadata Type

| Field | Value |
|-------|-------|
| Label | AI Config |
| Plural Label | AI Configs |
| Object Name | AI_Config |

### Add Custom Fields:

| Field Label | API Name | Type | Length |
|-------------|----------|------|--------|
| Is Active | Is_Active__c | Checkbox | - |
| Config Value | Config_Value__c | Text | 255 |
| Description | Description__c | Text Area | 255 |

### Create These Records (Manage AI Config):

| Label | DeveloperName | Is_Active__c | Config_Value__c | Description__c |
|-------|---------------|-------------|-----------------|----------------|
| Account AI Access | Account_AI_Access | ✓ (true) | | Enable AI access to Account data |
| Case AI Access | Case_AI_Access | ✓ (true) | | Enable AI access to Case data |
| Case AI Creation | Case_AI_Creation | ✓ (true) | | Allow AI to create Cases |
| Case AI Update | Case_AI_Update | ✓ (true) | | Allow AI to update Cases |
| Case Auto Escalation | Case_Auto_Escalation | ✓ (true) | | Auto-escalate high priority AI cases |
| Allowed Objects | Allowed_Objects | ✓ (true) | Account,Case,Contact | Objects AI is allowed to access |
| Max Daily AI Calls | Max_Daily_AI_Calls | ✓ (true) | 1000 | Maximum AI API calls per user per day |


## Step 6: Configure Security

### Set OWD (Organization-Wide Defaults):
- Setup → Sharing Settings
- Set Case: Private
- Set Account: Private (or Public Read Only for demo)

### Create Permission Set: AI_Integration_Admin
- Setup → Permission Sets → New
- Label: AI Integration Admin
- Give access to AI_Interaction_Log__c (Read, Create)
- Give access to all custom fields
- Assign to your user


## Step 7: Create Connected App (for OAuth)

Go to: Setup → App Manager → New Connected App

| Field | Value |
|-------|-------|
| Connected App Name | AI Integration App |
| API Name | AI_Integration_App |
| Contact Email | your email |
| Enable OAuth Settings | ✓ |
| Callback URL | https://localhost/callback |
| OAuth Scopes | Full access, API |

Save and note the Consumer Key and Consumer Secret.


## Step 8: Deploy Apex Classes

### Option A: VS Code + SFDX (Recommended)
```bash
sfdx auth:web:login -a AIProject
# Copy all .cls files to force-app/main/default/classes/
# Create corresponding .cls-meta.xml files for each class:
```

Meta XML template (create one per .cls file):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

Trigger meta XML template:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<ApexTrigger xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <status>Active</status>
</ApexTrigger>
```

### Option B: Developer Console
- Setup → Developer Console
- File → New → Apex Class
- Paste each class file
- Save


## Step 9: Deploy LWC Components

### Via VS Code + SFDX:
```bash
# Copy lwc folders to force-app/main/default/lwc/
sfdx force:source:deploy -p force-app/main/default/lwc -u AIProject
```

### Add to App Page:
- Setup → Lightning App Builder
- Create new App Page: "AI Integration Dashboard"
- Drag aiDashboard and aiConfigPanel components onto the page
- Save and Activate


## Step 10: Run Tests

```bash
sfdx force:apex:test:run -n AIAccountServiceTest,AICaseServiceTest,AIInteractionLoggerTest,AISecurityServiceTest,AIGovernanceServiceTest,AICaseEventSubscriberTest -u AIProject --resultformat human
```

Target: 95%+ code coverage


## Step 11: Test the REST Endpoints

### Get Access Token:
```bash
curl -X POST https://login.salesforce.com/services/oauth2/token \
  -d "grant_type=password" \
  -d "client_id=YOUR_CONSUMER_KEY" \
  -d "client_secret=YOUR_CONSUMER_SECRET" \
  -d "username=YOUR_USERNAME" \
  -d "password=YOUR_PASSWORD+SECURITY_TOKEN"
```

### Test GET Account:
```bash
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  https://YOUR_INSTANCE.salesforce.com/services/apexrest/ai/accounts/ACCOUNT_ID
```

### Test POST Case:
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"subject":"Test AI Case","description":"Urgent production issue","origin":"AI"}' \
  https://YOUR_INSTANCE.salesforce.com/services/apexrest/ai/cases/
```


## Step 12: Push to GitHub

```bash
git init
git add .
git commit -m "Initial commit: Secure AI-to-Salesforce Integration Platform"
git remote add origin https://github.com/ashishghaytadak/salesforce-ai-integration-platform.git
git push -u origin main
```


## DONE! 🎉

You now have a real, working project that proves every claim on your resume:
- ✅ Secure REST API endpoints (CRUD/FLS enforced)
- ✅ OAuth 2.0 authentication
- ✅ Multi-tenant data isolation (with sharing + OWD)
- ✅ Platform Events for async processing
- ✅ Audit logging (every AI interaction tracked)
- ✅ Governance controls (Custom Metadata admin config)
- ✅ LWC dashboard (monitoring + configuration)
- ✅ Test classes (95%+ coverage)
- ✅ GitHub repo (proof of work)
