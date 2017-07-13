/**
* @author Ben Edwards (ben@cloudinit.nz)
* @date 2017-07-12
* @description Take a given string with merge fields and replace with values
**/
public class FieldMergeUtil {

    // Set default start and end patterns
    // Can be changed or overriden in the methods
    public static final String DEFAULT_START_PATTERN = '{!';
    public static final String DEFAULT_END_PATTERN = '}';

    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Generate the string with the replaced values. Takes the record Id and executes the query as needed
    *   @return Returns the string with all merge fields replaced with values
    **/
    public static String replaceMergeFieldsWithValues (String stringToMerge, String recordId) {

        // Return the string with all the merge fields replaced with their values, yay!
        return replaceMergeFieldsWithValues (DEFAULT_START_PATTERN, DEFAULT_END_PATTERN, stringToMerge, recordId);
    }

    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Generate the string with the replaced values. Takes an already accepted SOBject record (so you need to make sure all necessary fields are queried)
    *                This method is bulkified, so could be done in a for loop, assuming query is executed first
    *   @return Returns the string with all merge fields replaced with values
    **/
    public static String replaceMergeFieldsWithValues (String stringToMerge, SObject record) {

        // Return the string with all the merge fields replaced with their values, yay!
        return replaceMergeFieldsWithValues (DEFAULT_START_PATTERN, DEFAULT_END_PATTERN, stringToMerge, record);
    }


    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Generate the string with the replaced values
    *   @return Returns the string with all merge fields replaced with values
    **/
    public static String replaceMergeFieldsWithValues (String startPattern, String endPattern, String stringToMerge, String recordId) {

        // Get the object name based on the recordId
        String objectName = ((Id) recordId).getSObjectType().getDescribe().getName();

        // Query for the SObject and all related fields
        SObject theRecord = getRecord (startPattern, endPattern, stringToMerge, objectName, recordId);

        return replaceMergeFieldsWithValues(startPattern, endPattern, stringToMerge, theRecord);
    }


    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Generate the string with the replaced values
    *   @return Returns the string with all merge fields replaced with values
    **/
    public static String replaceMergeFieldsWithValues (String startPattern, String endPattern, String stringToMerge, SObject theRecord) {

        // If blank, return a blank value
        if (String.isBlank(stringToMerge)) {

            return stringToMerge;
        }

        // The matcher which returns the matched fields from the given string
        Matcher theMatcher = thePattern(startPattern, endPattern).matcher(stringToMerge);

        // Iterate over each match
        while (theMatcher.find()) {

            // Get the field name based on the match
            String mergeField = theMatcher.group(1).trim();

            // Support getting parent fields for the object
            // Need to determine if there is a relationship in the field. This decides how many levels to go
            List<String> objectsAndField = mergeField.split('\\.');

            // The record to get the data from
            SObject theRecordForData = theRecord;

            // If there is a relationship
            if (objectsAndField.size() > 1) {

                // Run through the list but skip the last item (the field)
                for (Integer i = 0; i < objectsAndField.size() - 1; i++) {

                    // Only run if not null
                    // Will be null if the lookup field is blank
                    if (theRecordForData != null) {

                        // Get the new record to draw data from
                        theRecordForData = theRecordForData.getSObject(objectsAndField[i]);
                    }
                }

                // Since we should have the correct record now we can replace the list with only it's last item (the field)
                objectsAndField = new List<String>{objectsAndField[objectsAndField.size()-1]};
            }

            // Default merge value to blank string
            String mergeValue = '';

            // Process if the source record isn't null
            if (theRecordForData != null) {

                // Attempt to replace the merge value. If it fails, it will return a blank value
                try {

                    mergeValue = String.valueOf(theRecordForData.get(objectsAndField[0]));
                }
                catch (Exception ex) {

                    system.debug('### Error processing merge field "' + mergeField + '": ' + ex.getMessage() + '\n\n' + ex.getStackTraceString());
                }
            }

            // Set any null values to an empty string
            mergeValue = mergeValue == null ? '' : mergeValue;

            // Replace the matching field name with the value
            stringToMerge = stringToMerge.replace(startPattern + mergeField + endPattern, mergeValue);
        }

        // Return the string with all the merge fields replaced with their values, yay!
        return stringToMerge;
    }


    // The Pattern used for all merging. This is the {{ Field__c }} syntax.
    // You can replace this with your own merge sync (eg. <? Field__c ?> or {!Field__c}
    // Start pattern '{{ ' will be converted to '\\{\\{\\s'
    // Capturing group will be added '([^ + First Char of End Pattern + ]*)'
    // End pattern ' }}' will be converted to '\\s\\}\\}'
    private static Pattern thePattern(String startPattern, String endPattern) {

        // Make sure we have a pattern
        if (String.isBlank(startPattern.trim()) || String.isBlank(endPattern.trim())) {
            throw new FieldMergeUtilException('Start and End pattern required!');
        }

        // Regex to capture grouping
        String theRegex = '';

        // Convert the start pattern to regex
        for (String character : startPattern.split('')) {
            theRegex += character == ' ' ? '' : '\\' + character;
        }

        // Add Capturing Group to regex and include first end charcter to close grouping
        theRegex += '([^'+ endPattern.trim().left(1) +'}]*)';

        // Convert the end pattern to regex
        for (String character : endPattern.split('')) {
            theRegex += character == ' ' ? '' : '\\' + character;
        }

        // Replace all spaces with whitespace capturing
        theRegex = theRegex.replace(' ', '\\s');

        return Pattern.compile(theRegex);
    }

    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Do a dynamic SOQL query to get the record and required fields for the merging
    *   @return Return the SObject record
    **/
    public static SObject getRecord (String stringToMerge, String recordId) {

        // Get the object name based on the recordId
        String objectName = ((Id) recordId).getSObjectType().getDescribe().getName();

        return getRecord (DEFAULT_START_PATTERN, DEFAULT_END_PATTERN, stringToMerge, objectName, recordId);
    }


    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Do a dynamic SOQL query to get the record and required fields for the merging
    *   @return Return the SObject record
    **/
    public static SObject getRecord (String startPattern, String endPattern, String stringToMerge, String objectName, String recordId) {

        // The set of fields to query for
        Set<String> fieldsForQuery = new Set<String>();

        // The matcher which returns the matched fields from the given string
        Matcher theMatcher = thePattern(startPattern, endPattern).matcher(stringToMerge);

        // Loop through each match
        while (theMatcher.find()) {

            // Get the merge field from the match
            String mergeField = theMatcher.group(1).trim();

            // Determine if the field is valid or not
            if (fieldIsValid(objectName, mergeField)) {

                // Add the field name to the set
                fieldsForQuery.add(mergeField);
            }
        }

        // Build the query. The set of fields needs to be converted to a list to use String.join()
        String theQuery = 'SELECT ' + String.join(new List<String>(fieldsForQuery), ',');
        theQuery += ' FROM ' + objectName;
        theQuery += ' WHERE Id = \'' +  recordId + '\'';

        // Execute the query and record the record
        return Database.query(theQuery);
    }

    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Return true if the field is a valid field
    *   @return True for valid field, false for invalid
    **/
    public static Boolean fieldIsValid (String objectName, String mergeField) {

        Boolean fieldIsValid = true;

        // Split the merge field into a list for each lookup field
        List<String> objectsAndField = mergeField.split('\\.');

        // If only one, it's the base object. So check that
        if (objectsAndField.size() == 1) {

            // If the map contains the field API name, then it's valid
            fieldIsValid = objectNameToFieldsMap(objectName).get(objectName).containsKey(mergeField);
        }
        // Else it's a lookup. We need to go up to the parent field
        else {

            // Each time we go through a lookup, we need to update the current object name
            String currentObjectName = objectName;

            // Need to go up each object to valid the field for each object
            for (Integer i = 0; i < objectsAndField.size(); i++) {

                // Get the current field name
                String currentFieldName = objectsAndField[i];

                // If this is the last element, then it's the field we want to check
                // on the current object
                if (i == (objectsAndField.size() - 1)) {

                    // Then check if the field exists on the current object
                    fieldIsValid = objectNameToFieldsMap(currentObjectName).get(currentObjectName).containsKey(currentFieldName);
                }
                // Otherwise it's a lookup. We need to find the object name and go upwards.
                else {

                    // If a custom relationship, replace with __c
                    if (currentFieldName.endsWith('__r')) {

                        currentFieldName = currentFieldName.replace('__r','__c');
                    }
                    // Else it's a standard field, add Id on the end
                    else {

                        currentFieldName += 'Id';
                    }

                    // Check field exists on the current object
                    fieldIsValid = objectNameToFieldsMap(currentObjectName).get(currentObjectName).containsKey(currentFieldName);

                    // If it is valid (yay!) - update the object name for the next iteration
                    if (fieldIsValid) {

                        try {

                            // Describe the field
                            Schema.DescribeFieldResult fieldDescribe = objectNameToFieldsMap(currentObjectName).get(currentObjectName).get(currentFieldName).getDescribe();

                            // For name pointinng fields (fields with multiple object lookups. Eg. WhatId, WhoId etc)
                            if (fieldDescribe.isNamePointing()) {

                                // We're just going to trust it's ok.
                                // The merge will fall over if it's not ok, but the user
                                // can be responsible for that.
                                return true;
                            }
                            else {
                                // Run the get describe to get the parent field
                                // Will struggle if the lookup looks up to multiple
                                currentObjectName = fieldDescribe.getReferenceTo()[0].getDescribe().getName();
                            }
                        }
                        catch (Exception ex) {

                            system.debug(
                                'Could not get object name for lookup field ' + 
                                currentObjectName + '.' + currentFieldName + ': ' + 
                                ex.getMessage() + '\n\n' + ex.getStackTraceString()
                            );

                            return false;
                        }
                    }
                    else {

                        // If failed, return false
                        return fieldIsValid;
                    }
                }
            }
        }

        return fieldIsValid;
    }

    /**
    *   @author Ben Edwards (ben@cloudinit.nz)
    *   @description Build a map of Object API name to set of API fields. Used to determine if fields exist before executing the query
    *   @return Map of Object API name to set of API fields
    **/
    public static Map<String, Map<String, Schema.SObjectField>> objectNameToFieldsMap;
    public static Map<String, Map<String, Schema.SObjectField>> objectNameToFieldsMap (String objectName) {

        // If blank, instantiate new map
        if (objectNameToFieldsMap == null) {
            objectNameToFieldsMap = new Map<String, Map<String, Schema.SObjectField>>();
        }

        // If the object name doesn't exist in the map, add it.
        // If it does exist, no need to do anything as the fields will already be included
        if (!objectNameToFieldsMap.containsKey(objectName)) {

            objectNameToFieldsMap.put(
                objectName,
                Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap()
            );
        }

        return objectNameToFieldsMap;
    }

    // Custom Exceptions
    public class FieldMergeUtilException extends Exception {}
    
}