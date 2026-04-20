/**
 * AISecurityServiceTest
 * Tests CRUD/FLS checks and field masking
 */
@isTest
public class AISecurityServiceTest {

    @isTest
    static void testObjectAccessible() {
        Test.startTest();
        Boolean accessible = AISecurityService.isObjectAccessible('Account');
        Test.stopTest();
        System.assertEquals(true, accessible, 'Account should be accessible');
    }

    @isTest
    static void testMaskSensitiveFields() {
        Account testAcc = new Account(
            Name = 'Test Corp',
            Phone = '555-1234',
            Industry = 'Technology'
        );
        insert testAcc;

        Account queriedAcc = [SELECT Id, Name, Phone, Industry FROM Account WHERE Id = :testAcc.Id];
        Set<String> sensitiveFields = new Set<String>{'Phone'};

        Test.startTest();
        Map<String, Object> masked = AISecurityService.maskSensitiveFields(queriedAcc, sensitiveFields);
        Test.stopTest();

        System.assertEquals('***MASKED***', masked.get('Phone'), 'Phone should be masked');
        System.assertEquals('Test Corp', masked.get('Name'), 'Name should not be masked');
    }
}
