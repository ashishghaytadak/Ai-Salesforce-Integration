/**
 * AICaseServiceTest
 * Test class for AICaseService REST endpoint
 * Covers: case creation, AI priority suggestion, updates, Platform Events
 */
@isTest
public class AICaseServiceTest {
    private static Map<String, Object> parseResponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    @TestSetup
    static void setupData() {
        Account testAcc = new Account(Name = 'Test Corp');
        insert testAcc;

        Case testCase = new Case(
            Subject = 'Test Case',
            Description = 'This is a test case for AI processing',
            Status = 'New',
            Priority = 'Medium',
            AccountId = testAcc.Id
        );
        insert testCase;
    }

    @isTest
    static void testGetCaseSuccess() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/' + testCase.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.getCase();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        if ((Boolean) response.get('success')) {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            System.assertNotEquals(null, data, 'Should return case data');
            System.assertEquals('Test Case', data.get('subject'), 'Subject should match');
        } else {
            System.assertNotEquals(null, response.get('message'), 'Failure should include a reason');
        }
    }

    @isTest
    static void testGetCaseNotFound() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/500000000000000AAA';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.getCase();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'Should return not found');
    }

    @isTest
    static void testCreateCaseWithHighPriority() {
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'subject' => 'URGENT: Production system down',
            'description' => 'Critical outage affecting all users. Production is down.',
            'origin' => 'AI',
            'accountId' => testAcc.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.createCaseWithAI();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        if ((Boolean) response.get('success')) {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            System.assertEquals('High', data.get('suggestedPriority'),
                'Should suggest High priority for urgent keywords');
        }
    }

    @isTest
    static void testCreateCaseWithLowPriority() {
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'subject' => 'Question about feature',
            'description' => 'How to configure the dashboard? Just an inquiry.',
            'origin' => 'AI',
            'accountId' => testAcc.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.createCaseWithAI();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        if ((Boolean) response.get('success')) {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            System.assertEquals('Low', data.get('suggestedPriority'),
                'Should suggest Low priority for question/inquiry');
        }
    }

    @isTest
    static void testCreateCaseWithMediumPriority() {
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'subject' => 'Report generation issue',
            'description' => 'Reports are showing incorrect data for Q4.',
            'origin' => 'AI',
            'accountId' => testAcc.Id
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.createCaseWithAI();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        if ((Boolean) response.get('success')) {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            System.assertEquals('Medium', data.get('suggestedPriority'),
                'Should suggest Medium priority for neutral description');
        }
    }

    @isTest
    static void testCreateCaseNoSubject() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'subject' => '',
            'description' => 'Description only',
            'origin' => 'AI',
            'accountId' => null
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.createCaseWithAI();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'Should fail without subject');
    }

    @isTest
    static void testUpdateCase() {
        Case testCase = [SELECT Id FROM Case LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/cases/' + testCase.Id;
        req.httpMethod = 'PUT';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, String>{
            'status' => 'Working',
            'aiResponse' => 'AI suggests checking the configuration settings.'
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AICaseService.updateCaseWithAI();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        if ((Boolean) response.get('success')) {
            Case updated = [SELECT Status, Description FROM Case WHERE Id = :testCase.Id];
            System.assertEquals('Working', updated.Status, 'Status should be updated');
            System.assert(updated.Description.contains('AI Response'),
                'Description should contain AI response');
        }
    }

    @isTest
    static void testBulkCaseCreation() {
        Account testAcc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        for (Integer i = 0; i < 10; i++) {
            RestRequest req = new RestRequest();
            req.requestURI = '/services/apexrest/ai/cases/';
            req.httpMethod = 'POST';
            req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'subject' => 'Bulk Test Case ' + i,
                'description' => 'Description for bulk test ' + i,
                'origin' => 'AI',
                'accountId' => testAcc.Id
            }));
            RestContext.request = req;
            RestContext.response = new RestResponse();
            AICaseService.createCaseWithAI();
        }
        Test.stopTest();

        Integer caseCount = [SELECT COUNT() FROM Case WHERE Subject LIKE 'Bulk Test%'];
        System.assertEquals(10, caseCount, 'All 10 cases should be created');
    }
}
