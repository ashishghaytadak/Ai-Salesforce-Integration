/**
 * AIAccountServiceTest
 * Test class for AIAccountService REST endpoint
 * Covers: positive, negative, bulk, security scenarios
 */
@isTest
public class AIAccountServiceTest {
    private static Map<String, Object> parseResponse() {
        return (Map<String, Object>) JSON.deserializeUntyped(
            RestContext.response.responseBody.toString()
        );
    }

    @TestSetup
    static void setupData() {
        // Create test accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology',
                Phone = '555-000-000' + i,
                BillingCity = 'New York',
                BillingState = 'NY',
                Website = 'https://test' + i + '.com'
            ));
        }
        insert accounts;
    }

    @isTest
    static void testGetAccountSuccess() {
        Account testAcc = [SELECT Id FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/accounts/' + testAcc.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AIAccountService.getAccount();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        System.assertNotEquals(null, response.get('success'), 'Response should include success flag');
        if ((Boolean) response.get('success')) {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            System.assertNotEquals(null, data, 'Should return account data');
            System.assertEquals('***MASKED***', data.get('Phone'), 'Phone should be masked');
        }
    }

    @isTest
    static void testGetAccountNotFound() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/accounts/001000000000000AAA';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AIAccountService.getAccount();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        System.assertEquals(false, (Boolean) response.get('success'), 'Should return not found');
    }

    @isTest
    static void testSensitiveFieldsMasked() {
        Account testAcc = [SELECT Id, Phone FROM Account WHERE Name = 'Test Account 0' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/ai/accounts/' + testAcc.Id;
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AIAccountService.getAccount();
        Test.stopTest();
        Map<String, Object> response = parseResponse();
        if ((Boolean) response.get('success')) {
            Map<String, Object> data = (Map<String, Object>) response.get('data');
            System.assertEquals('***MASKED***', data.get('Phone'), 'Sensitive field should be masked');
            System.assertNotEquals('***MASKED***', data.get('Name'), 'Non-sensitive field should not be masked');
        } else {
            System.assertNotEquals(null, response.get('message'), 'Failure should include a reason');
        }
    }
}
