import { LightningElement, wire } from 'lwc';
import getAllConfigs from '@salesforce/apex/AIGovernanceService.getAllConfigs';

const COLUMNS = [
    { label: 'Feature', fieldName: 'Label', type: 'text' },
    { label: 'API Name', fieldName: 'DeveloperName', type: 'text' },
    { label: 'Active', fieldName: 'Is_Active__c', type: 'boolean' },
    { label: 'Value', fieldName: 'Config_Value__c', type: 'text' },
    { label: 'Description', fieldName: 'Description__c', type: 'text' }
];

export default class AiConfigPanel extends LightningElement {
    columns = COLUMNS;
    configs;
    error;

    @wire(getAllConfigs)
    wiredConfigs({ error, data }) {
        if (data) {
            this.configs = data;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.configs = undefined;
        }
    }

    refreshConfigs() {
        return getAllConfigs()
            .then(data => {
                this.configs = data;
            })
            .catch(error => {
                this.error = error;
            });
    }
}
