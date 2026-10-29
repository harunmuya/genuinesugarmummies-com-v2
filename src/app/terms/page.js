import PolicyDocument from '@/components/PolicyDocument';

export const metadata = { title: 'Terms and Conditions - Genuine Sugarmummies' };

export default function TermsPage() {
    return <PolicyDocument
        title="Terms and Conditions"
        eyebrow="Using the app"
        icon="gavel"
        summary="These terms explain the basic conditions for using the Genuine Sugarmummies app. The app is an adult introductions and communication service; it cannot decide whether two people are compatible or promise a particular outcome."
        sections={[
            {
                icon: 'person',
                title: 'Who may create an account',
                paragraphs: [
                    'You must be at least 18 years old to register, browse member areas, or use the app. Do not create an account for another person, misstate your age, or continue using the service if you know the account is being used by a minor.',
                    'Use an email address and username you control. Keep your password and reset codes private. You are responsible for activity carried out through your account and should contact support promptly if you believe another person has accessed it.'
                ]
            },
            {
                icon: 'badge',
                title: 'Account and profile information',
                paragraphs: [
                    'Provide information that is accurate to the best of your knowledge and that you are entitled to share. Your registered profile category is fixed after account creation; your preferences about whom you are looking for can be changed in account settings.',
                    'Profile visibility, age display, and online-status preferences control how some details appear in discovery. Moderation may hide or restrict information while a safety or authenticity concern is reviewed. A badge records a review step; it is not a guarantee of identity, image origin, availability, conduct, compatibility, or safety.'
                ]
            },
            {
                icon: 'image',
                title: 'Photos, messages, and permission',
                paragraphs: [
                    'Upload only photographs and material you own or have permission to use. Do not impersonate another person, publish private material without consent, or use someone else\'s identity documents. Do not send passwords, one-time codes, or mobile-money PINs in messages.',
                    'Messages and profile submissions are used to provide the service and help address reports or disputes. Treat another member\'s contact details and private messages as confidential unless they have clearly agreed to share them.'
                ]
            },
            {
                icon: 'payments',
                title: 'Fees, offers, and payment review',
                paragraphs: [
                    'The standard local introduction fee is KSh 750. Eligible members using the app may submit a KSh 650 local-connection offer request. An offer is not claimed until an administrator checks the transaction reference against the payment record and approves the request.',
                    'Pay only the recipient and amount shown in the app, and verify the recipient in your mobile-money application before confirming. Payment requests are reviewed manually. A submitted transaction ID is not proof of payment, and an approval does not guarantee that a particular member will respond or accept an introduction.',
                    'App package access and introduction requests are separate services. Package access is not a payment to a profile owner and does not buy consent, a reply, a meeting, a relationship, marriage, or financial support. Any currently displayed package terms and prices apply at the time you submit the request.'
                ]
            },
            {
                icon: 'favorite',
                title: 'Consent and member decisions',
                paragraphs: [
                    'A profile, like, match, message, payment, or introduction request is not consent to meet, continue a conversation, start a relationship, or provide financial support. Each person makes those decisions freely and may change their mind.',
                    'The desk coordinates requests but does not make decisions for members. Availability can change, and the service cannot promise that a member will answer or that an introduction will be suitable.'
                ]
            },
            {
                icon: 'block',
                title: 'Conduct that is not allowed',
                paragraphs: [
                    'Do not harass, threaten, stalk, coerce, exploit, defraud, extort, impersonate, or discriminate against another person. Do not use the service for spam, unlawful activity, or attempts to obtain passwords, payment credentials, or intimate material through pressure.',
                    'Do not upload content that violates another person\'s privacy or rights. Do not evade a restriction by creating another account. Raise concerns through the reporting and support route instead of retaliating or publishing private information.'
                ]
            },
            {
                icon: 'admin_panel_settings',
                title: 'Review and account action',
                paragraphs: [
                    'The desk may review profile submissions, payment references, and safety reports. It may hide content, pause a feature, or restrict an account while checking a credible concern or enforcing these terms.',
                    'If an action affects your account, contact support with the relevant account email and a concise explanation. Do not include your password, reset code, or payment PIN.'
                ]
            },
            {
                icon: 'info',
                title: 'Service limits and changes',
                paragraphs: [
                    'The app and its features may be updated, interrupted, or changed to maintain the service and respond to safety or technical needs. We will make reasonable efforts to keep account and payment information accurate, but app availability is not guaranteed without interruption.',
                    'These terms describe the service in plain language and are not a promise of a particular personal, financial, or relationship result. For help about a specific account or payment, use the support page.'
                ]
            }
        ]}
    />;
}
