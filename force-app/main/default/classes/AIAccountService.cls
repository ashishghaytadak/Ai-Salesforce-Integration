/**
 * AIAccountService
 * Secure REST API endpoint for external AI systems to query Account data.
 * 
 * Endpoint: /services/apexrest/ai/accounts/{accountId}
 * Auth: OAuth 2.0 via Connected App
 * 
 * Security:
 * - 'with sharing' enforces current user's sharing rules (data isolation)
 * - CRUD/FLS checks before every data access
 * - Sensitive fields masked before response
 * - Every interaction logged for audit
 * - Governance checks (feature toggle, rate limiting)
 */
@RestResource(urlMapping='/ai/accounts/*')
global with sharing class AIAccountService {

    // Fields considered sensitive - masked before sending to AI
    private static final Set<String> SENSITIVE_FIELDS = new Set<String>{
        'Phone', 'Fax', 'BillingStreet', 'ShippingStreet'
    };

    /**
     * GET /ai/accounts/{accountId}
     * Returns account data with sensitive fields masked
     */
    @HttpGet
    global static void getAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(
            req.requestURI.lastIndexOf('/') + 1
        );

        try {
            // Step 1: Governance check - is this feature enabled?
            if (!AIGovernanceService.isFeatureEnabled('Account_AI_Access')) {
                sendResponse(false, 'AI Account access is currently disabled by admin.', null);
                return;
            }

            // Step 2: Governance check - is AI allowed to access Account object?
            if (!AIGovernanceService.isObjectAllowedForAI('Account')) {
                sendResponse(false, 'Account object is not in the AI allowed list.', null);
                return;
            }

            // Step 3: Rate limiting check
            if (!AIGovernanceService.isWithinRateLimit(UserInfo.getUserId())) {
                sendResponse(false, 'Rate limit exceeded. Try again tomorrow.', null);
                return;
            }

            // Step 4: CRUD security check
            if (!AISecurityService.isObjectAccessible('Account')) {
                AIInteractionLogger.logInteraction(
                    'GET_ACCOUNT', accountId, null, null, 'ACCESS_DENIED'
                );
                sendResponse(false, 'Insufficient access to Account object.', null);
                return;
            }

            // Step 5: Query the account ('with sharing' enforces data isolation)
            List<Account> accounts = [
                SELECT Id, Name, Industry, Type, Website, 
                       Phone, BillingCity, BillingState,
                       NumberOfEmployees, AnnualRevenue
                FROM Account
                WHERE Id = :accountId
                LIMIT 1
            ];

            if (accounts.isEmpty()) {
                AIInteractionLogger.logInteraction(
                    'GET_ACCOUNT', accountId, null, null, 'NOT_FOUND'
                );
                sendResponse(false, 'Account not found or access denied.', null);
                return;
            }

            // Step 6: Mask sensitive fields before responding
            Map<String, Object> safeData = AISecurityService.maskSensitiveFields(
                accounts[0], SENSITIVE_FIELDS
            );

            // Step 7: Log successful interaction
            AIInteractionLogger.logInteractionAsync(
                'GET_ACCOUNT', accountId, 
                JSON.serialize(safeData), 'SUCCESS'
            );

            sendResponse(true, 'Account retrieved successfully.', safeData);
            return;

        } catch (Exception e) {
            AIInteractionLogger.logInteraction(
                'GET_ACCOUNT', accountId, null, e.getMessage(), 'ERROR'
            );
            sendResponse(false, 'Error: ' + e.getMessage(), null);
            return;
        }
    }

    private static void sendResponse(Boolean success, String message, Map<String, Object> data) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(
            JSON.serialize(new AIResponse(success, message, data))
        );
    }

    /**
     * Response wrapper class for consistent API responses
     */
    global class AIResponse {
        public Boolean success;
        public String message;
        public Map<String, Object> data;
        public DateTime timestamp;

        public AIResponse(Boolean success, String message, Map<String, Object> data) {
            this.success = success;
            this.message = message;
            this.data = data;
            this.timestamp = DateTime.now();
        }
    }
}
