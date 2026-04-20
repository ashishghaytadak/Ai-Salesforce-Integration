/**
 * AISecurityService
 * Centralized security utility for CRUD/FLS enforcement.
 * Used by all REST endpoints before accessing or modifying data.
 * Ensures compliance with Salesforce Security Review standards.
 */
public with sharing class AISecurityService {

    /**
     * Check if the current user has READ access to an sObject
     */
    public static Boolean isObjectAccessible(String objectName) {
        Schema.DescribeSObjectResult describe = 
            Schema.getGlobalDescribe().get(objectName).getDescribe();
        return describe.isAccessible();
    }

    /**
     * Check if the current user has CREATE access to an sObject
     */
    public static Boolean isObjectCreateable(String objectName) {
        Schema.DescribeSObjectResult describe = 
            Schema.getGlobalDescribe().get(objectName).getDescribe();
        return describe.isCreateable();
    }

    /**
     * Check if the current user has UPDATE access to an sObject
     */
    public static Boolean isObjectUpdateable(String objectName) {
        Schema.DescribeSObjectResult describe = 
            Schema.getGlobalDescribe().get(objectName).getDescribe();
        return describe.isUpdateable();
    }

    /**
     * Check if a specific field is accessible to the current user
     */
    public static Boolean isFieldAccessible(String objectName, String fieldName) {
        Schema.DescribeFieldResult field = 
            Schema.getGlobalDescribe().get(objectName)
            .getDescribe().fields.getMap()
            .get(fieldName).getDescribe();
        return field.isAccessible();
    }

    /**
     * Mask sensitive fields before sending data to external AI system.
     * Prevents PII leakage outside Salesforce trust boundary.
     */
    public static Map<String, Object> maskSensitiveFields(
        SObject record, 
        Set<String> sensitiveFieldNames
    ) {
        Map<String, Object> safeData = new Map<String, Object>();
        Map<String, Object> recordMap = record.getPopulatedFieldsAsMap();

        for (String fieldName : recordMap.keySet()) {
            if (sensitiveFieldNames.contains(fieldName)) {
                safeData.put(fieldName, '***MASKED***');
            } else {
                safeData.put(fieldName, recordMap.get(fieldName));
            }
        }
        return safeData;
    }

    /**
     * Validate that all required fields are present in the request
     */
    public static void validateRequiredFields(
        Map<String, Object> requestData, 
        List<String> requiredFields
    ) {
        List<String> missingFields = new List<String>();
        for (String field : requiredFields) {
            if (!requestData.containsKey(field) || requestData.get(field) == null) {
                missingFields.add(field);
            }
        }
        if (!missingFields.isEmpty()) {
            throw new AISecurityException(
                'Missing required fields: ' + String.join(missingFields, ', ')
            );
        }
    }

    public class AISecurityException extends Exception {}
}
