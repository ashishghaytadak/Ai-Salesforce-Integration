/**
 * AICaseService
 * Secure REST API endpoint for AI-driven case handling.
 * 
 * Endpoint: /services/apexrest/ai/cases/{caseId}
 * Auth: OAuth 2.0 via Connected App
 * 
 * Features:
 * - GET: Retrieve case details for AI analysis
 * - POST: Create case with AI-suggested assignment
 * - PUT: Update case with AI-generated response/resolution
 * - Platform Event fired for async AI processing
 */
@RestResource(urlMapping='/ai/cases/*')
global with sharing class AICaseService {

    /**
     * GET /ai/cases/{caseId}
     * Returns case details for AI to analyze and suggest resolution
     */
    @HttpGet
    global static void getCase() {
        RestRequest req = RestContext.request;
        String caseId = req.requestURI.substring(
            req.requestURI.lastIndexOf('/') + 1
        );

        try {
            // Governance + security checks
            if (!AIGovernanceService.isFeatureEnabled('Case_AI_Access')) {
                sendResponse(false, 'AI Case access is disabled.', null);
                return;
            }

            if (!AISecurityService.isObjectAccessible('Case')) {
                AIInteractionLogger.logInteraction(
                    'GET_CASE', caseId, null, null, 'ACCESS_DENIED'
                );
                sendResponse(false, 'Insufficient access.', null);
                return;
            }

            if (!AIGovernanceService.isWithinRateLimit(UserInfo.getUserId())) {
                sendResponse(false, 'Rate limit exceeded.', null);
                return;
            }

            // Query case with sharing rules enforced
            List<Case> cases = [
                SELECT Id, CaseNumber, Subject, Description, Status,
                       Priority, Origin, Type, ContactId, AccountId,
                       Account.Name, Contact.Name, CreatedDate
                FROM Case
                WHERE Id = :caseId
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                sendResponse(false, 'Case not found or access denied.', null);
                return;
            }

            Case c = cases[0];
            Map<String, Object> caseData = new Map<String, Object>{
                'id' => c.Id,
                'caseNumber' => c.CaseNumber,
                'subject' => c.Subject,
                'description' => c.Description,
                'status' => c.Status,
                'priority' => c.Priority,
                'origin' => c.Origin,
                'type' => c.Type,
                'accountName' => c.Account?.Name,
                'contactName' => c.Contact?.Name,
                'createdDate' => c.CreatedDate
            };

            // Log successful retrieval
            AIInteractionLogger.logInteractionAsync(
                'GET_CASE', caseId, JSON.serialize(caseData), 'SUCCESS'
            );

            sendResponse(true, 'Case retrieved.', caseData);
            return;

        } catch (Exception e) {
            AIInteractionLogger.logInteraction(
                'GET_CASE', caseId, null, e.getMessage(), 'ERROR'
            );
            sendResponse(false, 'Error: ' + e.getMessage(), null);
            return;
        }
    }

    /**
     * POST /ai/cases/
     * Creates a new case with AI-suggested priority and assignment.
     * Fires a Platform Event for async AI processing.
     */
    @HttpPost
    global static void createCaseWithAI() {
        try {
            Map<String, Object> requestBody = (Map<String, Object>)
                JSON.deserializeUntyped(RestContext.request.requestBody.toString());
            String subject = (String) requestBody.get('subject');
            String description = (String) requestBody.get('description');
            String origin = (String) requestBody.get('origin');
            String accountId = (String) requestBody.get('accountId');

            // Governance check
            if (!AIGovernanceService.isFeatureEnabled('Case_AI_Creation')) {
                sendResponse(false, 'AI Case creation is disabled.', null);
                return;
            }

            // CRUD check
            if (!AISecurityService.isObjectCreateable('Case')) {
                sendResponse(false, 'Insufficient access to create Cases.', null);
                return;
            }

            // Validate required fields
            if (String.isBlank(subject)) {
                sendResponse(false, 'Subject is required.', null);
                return;
            }

            // AI-suggested priority based on keywords in description
            String suggestedPriority = suggestPriority(description);

            // Create the case
            Case newCase = new Case(
                Subject = subject,
                Description = description,
                Origin = origin != null ? origin : 'AI',
                Priority = suggestedPriority,
                Status = 'New',
                AccountId = accountId
            );
            insert newCase;

            // Fire Platform Event for async AI processing
            fireAICaseEvent(newCase.Id, 'NEW_CASE', suggestedPriority);

            // Log the interaction
            AIInteractionLogger.logInteractionAsync(
                'CREATE_CASE', newCase.Id,
                JSON.serialize(new Map<String, String>{
                    'subject' => subject,
                    'suggestedPriority' => suggestedPriority
                }),
                'SUCCESS'
            );

            Map<String, Object> responseData = new Map<String, Object>{
                'caseId' => newCase.Id,
                'suggestedPriority' => suggestedPriority,
                'status' => 'New'
            };

            sendResponse(true, 'Case created with AI-suggested priority.', responseData);
            return;

        } catch (Exception e) {
            AIInteractionLogger.logInteraction(
                'CREATE_CASE', null, null, e.getMessage(), 'ERROR'
            );
            sendResponse(false, 'Error: ' + e.getMessage(), null);
            return;
        }
    }

    /**
     * PUT /ai/cases/{caseId}
     * Updates case with AI-generated response or status change
     */
    @HttpPut
    global static void updateCaseWithAI() {
        RestRequest req = RestContext.request;
        String caseId = req.requestURI.substring(
            req.requestURI.lastIndexOf('/') + 1
        );

        try {
            // Governance check
            if (!AIGovernanceService.isFeatureEnabled('Case_AI_Update')) {
                sendResponse(false, 'AI Case updates are disabled.', null);
                return;
            }

            // CRUD check
            if (!AISecurityService.isObjectUpdateable('Case')) {
                sendResponse(false, 'Insufficient access to update Cases.', null);
                return;
            }

            // Parse request body
            Map<String, Object> requestBody = (Map<String, Object>) 
                JSON.deserializeUntyped(req.requestBody.toString());

            // Query existing case (sharing rules enforced)
            List<Case> cases = [
                SELECT Id, Status, Priority 
                FROM Case 
                WHERE Id = :caseId 
                LIMIT 1
            ];

            if (cases.isEmpty()) {
                sendResponse(false, 'Case not found or access denied.', null);
                return;
            }

            Case existingCase = cases[0];

            // Apply AI-suggested updates
            if (requestBody.containsKey('status')) {
                existingCase.Status = (String) requestBody.get('status');
            }
            if (requestBody.containsKey('priority')) {
                existingCase.Priority = (String) requestBody.get('priority');
            }
            if (requestBody.containsKey('aiResponse')) {
                existingCase.Description = existingCase.Description + 
                    '\n\n--- AI Response ---\n' + (String) requestBody.get('aiResponse');
            }

            update existingCase;

            // Fire Platform Event for downstream processing
            fireAICaseEvent(caseId, 'UPDATE_CASE', existingCase.Priority);

            // Log interaction
            AIInteractionLogger.logInteractionAsync(
                'UPDATE_CASE', caseId,
                JSON.serialize(requestBody), 'SUCCESS'
            );

            sendResponse(
                true,
                'Case updated by AI.',
                new Map<String, Object>{ 'caseId' => caseId, 'status' => existingCase.Status }
            );
            return;

        } catch (Exception e) {
            AIInteractionLogger.logInteraction(
                'UPDATE_CASE', caseId, null, e.getMessage(), 'ERROR'
            );
            sendResponse(false, 'Error: ' + e.getMessage(), null);
            return;
        }
    }

    private static void sendResponse(Boolean success, String message, Map<String, Object> data) {
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(
            JSON.serialize(new CaseResponse(success, message, data))
        );
    }

    /**
     * AI Priority Suggestion Engine
     * Analyzes description keywords to suggest priority level
     */
    private static String suggestPriority(String description) {
        if (description == null) return 'Medium';

        String lowerDesc = description.toLowerCase();

        // High priority keywords
        Set<String> highKeywords = new Set<String>{
            'urgent', 'critical', 'down', 'outage', 'emergency', 
            'security breach', 'data loss', 'production'
        };

        // Low priority keywords
        Set<String> lowKeywords = new Set<String>{
            'question', 'inquiry', 'info', 'how to', 'feature request',
            'nice to have', 'when available'
        };

        for (String keyword : highKeywords) {
            if (lowerDesc.contains(keyword)) return 'High';
        }

        for (String keyword : lowKeywords) {
            if (lowerDesc.contains(keyword)) return 'Low';
        }

        return 'Medium';
    }

    /**
     * Publish Platform Event for async AI processing
     */
    private static void fireAICaseEvent(String caseId, String action, String priority) {
        AI_Case_Event__e evt = new AI_Case_Event__e(
            Case_Id__c = caseId,
            Action__c = action,
            Priority__c = priority
        );
        EventBus.publish(evt);
    }

    /**
     * Response wrapper for Case endpoints
     */
    global class CaseResponse {
        public Boolean success;
        public String message;
        public Map<String, Object> data;
        public DateTime timestamp;

        public CaseResponse(Boolean success, String message, Map<String, Object> data) {
            this.success = success;
            this.message = message;
            this.data = data;
            this.timestamp = DateTime.now();
        }
    }
}
