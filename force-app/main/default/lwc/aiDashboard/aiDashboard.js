import { LightningElement, wire, track } from 'lwc';
import getRecentLogs from '@salesforce/apex/AIInteractionLogger.getRecentLogs';

const COLUMNS = [
    { label: 'Timestamp', fieldName: 'Timestamp__c', type: 'date',
      typeAttributes: { 
        year: 'numeric', month: 'short', day: '2-digit',
        hour: '2-digit', minute: '2-digit'
      }, sortable: true },
    { label: 'Action', fieldName: 'Action__c', type: 'text', sortable: true },
    { label: 'Record ID', fieldName: 'Record_Id__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text', sortable: true,
      cellAttributes: {
        class: { fieldName: 'statusClass' }
      }
    },
    { label: 'User', fieldName: 'User_Name__c', type: 'text' }
];

export default class AiDashboard extends LightningElement {
    columns = COLUMNS;
    logs = [];
    error;
    sortedBy = 'Timestamp__c';
    sortedDirection = 'desc';

    // Summary stats
    totalInteractions = 0;
    successCount = 0;
    errorCount = 0;
    deniedCount = 0;

    get noLogs() {
        return this.logs.length === 0;
    }

    @wire(getRecentLogs, { limitCount: 50 })
    wiredLogs({ error, data }) {
        if (data) {
            this.logs = data.map(log => ({
                ...log,
                statusClass: this.getStatusClass(log.Status__c)
            }));
            this.calculateStats();
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.logs = [];
        }
    }

    calculateStats() {
        this.totalInteractions = this.logs.length;
        this.successCount = this.logs.filter(
            log => log.Status__c === 'SUCCESS'
        ).length;
        this.errorCount = this.logs.filter(
            log => log.Status__c === 'ERROR'
        ).length;
        this.deniedCount = this.logs.filter(
            log => log.Status__c === 'ACCESS_DENIED'
        ).length;
    }

    getStatusClass(status) {
        switch (status) {
            case 'SUCCESS': return 'slds-text-color_success';
            case 'ERROR': return 'slds-text-color_error';
            case 'ACCESS_DENIED': return 'slds-text-color_error';
            default: return '';
        }
    }

    handleSort(event) {
        this.sortedBy = event.detail.fieldName;
        this.sortedDirection = event.detail.sortDirection;
        this.sortData(this.sortedBy, this.sortedDirection);
    }

    sortData(fieldName, direction) {
        let parseData = JSON.parse(JSON.stringify(this.logs));
        let isReverse = direction === 'asc' ? 1 : -1;
        
        parseData.sort((a, b) => {
            a = a[fieldName] ? a[fieldName] : '';
            b = b[fieldName] ? b[fieldName] : '';
            return isReverse * ((a > b) - (b > a));
        });
        
        this.logs = parseData;
    }

    refreshLogs() {
        // Force refresh by re-evaluating the wire
        return getRecentLogs({ limitCount: 50 })
            .then(data => {
                this.logs = data.map(log => ({
                    ...log,
                    statusClass: this.getStatusClass(log.Status__c)
                }));
                this.calculateStats();
            })
            .catch(error => {
                this.error = error;
            });
    }
}
