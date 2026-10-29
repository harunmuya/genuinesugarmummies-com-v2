import PolicyDocument from '@/components/PolicyDocument';

export const metadata = { title: 'Privacy Policy - Genuine Sugarmummies' };

export default function PrivacyPage() {
    return <PolicyDocument
        title="Privacy Policy"
        eyebrow="Your information"
        icon="privacy_tip"
        summary="This policy describes the information the app handles, why it is needed, and the controls available to members. The app is separate from the public WordPress website, and account information is used to operate the app rather than to create public search listings."
        sections={[
            {
                icon: 'person',
                title: 'Information you provide',
                paragraphs: [
                    'Registration uses an email address, username, password, age confirmation, and profile details such as display name, location, phone number, biography, preferences, and photographs. You may also submit verification material, a support request, or a safety report.',
                    'Payment review may include a transaction reference, payment method, requested amount, request status, and administrator notes. Never include a mobile-money PIN, password, or one-time code in a payment reference or support message.'
                ]
            },
            {
                icon: 'settings',
                title: 'Information created while you use the app',
                paragraphs: [
                    'The app processes profile views, likes, matches, saved profiles, messages, call activity, and other interactions needed to provide member features. Technical information such as device, browser, and connection data may be processed by the hosting and service providers that deliver the app.',
                    'Some features use an approximate or current location when you choose to provide or enable it. You can disable live location in account settings or through your device permissions; location-based features may then be less accurate or unavailable.'
                ]
            },
            {
                icon: 'visibility',
                title: 'What other members can see',
                paragraphs: [
                    'Your profile visibility setting controls whether your account is included in member discovery. Separate controls determine whether age or online status is displayed. These settings are designed to take effect in discovery and related app views after they are saved.',
                    'Information you choose to place in a public profile can be seen by other app members. Do not include a home address, private identity number, workplace details, or information about someone else that you do not want members to see.'
                ]
            },
            {
                icon: 'verified_user',
                title: 'Verification and profile submissions',
                paragraphs: [
                    'Verification material and private profile submissions are available to authorized desk staff for review. The review process supports moderation and publication decisions; it does not establish a guarantee of identity, image origin, safety, or future availability.',
                    'Only share images and details you are entitled to provide. If you want a profile hidden or a submitted detail corrected, contact support and identify the account or item concerned without sending sensitive credentials.'
                ]
            },
            {
                icon: 'mark_email_read',
                title: 'How information is used',
                paragraphs: [
                    'Information is used to create and secure accounts, show profiles according to settings, apply member preferences, support messaging and matches, process payment reviews, deliver notifications, investigate reports, prevent abuse, and answer support requests.',
                    'Email and device notification preferences can be changed in the app. Your browser or phone may also provide separate permission controls. Turning notifications off does not delete messages or close an account.'
                ]
            },
            {
                icon: 'share',
                title: 'Service providers and disclosures',
                paragraphs: [
                    'The app relies on hosting, database, email, and push-notification services to operate. Those providers process information needed to deliver their service. Payment transaction references are reviewed by the desk against the relevant payment record; members should not pay profile owners through the app.',
                    'Information may also be used or disclosed when necessary to address a safety report, enforce the terms, respond to a lawful request, or protect members and the service. We do not claim that information is never shared or that every provider has identical retention practices.'
                ]
            },
            {
                icon: 'schedule',
                title: 'Retention, access, and deletion requests',
                paragraphs: [
                    'Information is kept for as long as needed to operate the account and handle safety, payment, moderation, and support matters. Some records may need to remain available for an appropriate period to resolve payment questions, prevent repeat abuse, or meet legal obligations; a fixed deletion deadline is not promised here.',
                    'Use the support page to request access, correction, profile hiding, or account deletion. We may need to verify that the request comes from the account holder before acting. A deletion request may not remove records that must be retained for a specific operational or legal reason.'
                ]
            },
            {
                icon: 'lock',
                title: 'Account security and policy updates',
                paragraphs: [
                    'Choose a password that you do not reuse elsewhere, sign out of shared devices, and tell support if you suspect unauthorized access. No online service can promise absolute security, so avoid sending secrets or identity documents through ordinary member chat.',
                    'This policy may be updated when app features or data practices change. The current version will be published on this page. Contact support if you need help understanding how a particular setting affects your profile.'
                ]
            }
        ]}
    />;
}
