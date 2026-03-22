import { ISponsor } from './ISponsor';

/**
 * Realistic-looking but entirely fictitious sponsor records used when demo
 * mode is enabled in the property pane.  No Graph calls are made; these
 * objects are returned directly so that the web part can be previewed in the
 * local workbench without a tenant connection or a guest account.
 */
export const MOCK_SPONSORS: ISponsor[] = [
  {
    id: 'mock-1',
    displayName: 'Anna Müller',
    givenName: 'Anna',
    surname: 'Müller',
    mail: 'anna.mueller@contoso.com',
    jobTitle: 'IT Manager',
    department: 'Information Technology',
    officeLocation: 'BER-HQ / Bldg A / Floor 4 / A4-12',
    city: 'Berlin',
    country: 'Germany',
    businessPhones: ['+49 30 12345678'],
    mobilePhone: undefined,
    photoUrl: undefined,
    presence: 'Available',
    presenceActivity: 'Available',
    hasTeams: true,
    managerDisplayName: 'Thomas Schneider',
    managerGivenName: 'Thomas',
    managerSurname: 'Schneider',
    managerJobTitle: 'Head of IT',
    managerDepartment: 'Information Technology',
    managerPhotoUrl: undefined,
  },
  {
    id: 'mock-2',
    displayName: 'James Anderson',
    givenName: 'James',
    surname: 'Anderson',
    mail: 'james.anderson@contoso.com',
    jobTitle: 'Project Lead',
    department: 'Business Development',
    officeLocation: 'MUC-03 / Bldg C / Floor 2 / C2-08',
    city: 'Munich',
    country: 'Germany',
    businessPhones: [],
    mobilePhone: '+49 151 98765432',
    photoUrl: undefined,
    presence: 'Busy',
    presenceActivity: 'InAMeeting',
    hasTeams: true,
    managerDisplayName: 'Sarah Webb',
    managerGivenName: 'Sarah',
    managerSurname: 'Webb',
    managerJobTitle: 'VP Business Development',
    managerDepartment: 'Business Development',
    managerPhotoUrl: undefined,
  },
];
