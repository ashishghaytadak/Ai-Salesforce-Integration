/**
 * AIGovernanceServiceTest
 * Tests governance configuration behavior
 */
@isTest
public class AIGovernanceServiceTest {

    @isTest
    static void testFeatureDisabledByDefault() {
        Test.startTest();
        Boolean enabled = AIGovernanceService.isFeatureEnabled('Nonexistent_Feature');
        Test.stopTest();

        System.assertEquals(false, enabled, 'Non-existent feature should default to disabled');
    }

    @isTest
    static void testGetConfigValueNull() {
        Test.startTest();
        String value = AIGovernanceService.getConfigValue('Nonexistent_Config');
        Test.stopTest();

        System.assertEquals(null, value, 'Non-existent config should return null');
    }
}
