import PolicyDocument from '@/components/PolicyDocument';

export const metadata = { title: 'Safety Center - Genuine Sugarmummies' };

export default function SafetyPage() {
    return <PolicyDocument
        title="Safety Center"
        eyebrow="Make informed choices"
        icon="health_and_safety"
        summary="The desk can help coordinate an introduction, but you remain responsible for your decisions and boundaries. Read these practical safeguards before sharing information, paying a fee, or arranging to meet someone."
        sections={[
            {
                icon: 'payments',
                title: 'Check every payment instruction',
                paragraphs: [
                    'Use only the payment method, recipient, and amount displayed in the app. Before confirming a transfer, check the recipient details inside your mobile-money service. If a message asks you to pay a profile owner directly or use a different number, stop and contact support.',
                    'The standard local introduction fee is KSh 750. An eligible app offer may allow a KSh 650 request. Transaction references are checked manually by an administrator; submitting a reference does not mean payment has been confirmed. Never share your payment PIN or one-time code.'
                ]
            },
            {
                icon: 'badge',
                title: 'Understand what a profile review means',
                paragraphs: [
                    'A review or badge records a moderation step based on material available at the time. It cannot prove who took a photograph, guarantee identity, predict future conduct, or confirm that a member will remain available.',
                    'Do not treat a profile, badge, testimonial, or desk message as a substitute for your own judgement. Ask questions directly, move at a pace that feels comfortable, and stop if the information or request feels inconsistent.'
                ]
            },
            {
                icon: 'lock',
                title: 'Protect private information',
                paragraphs: [
                    'Keep your password, reset code, mobile-money PIN, identity numbers, and private documents to yourself. A desk representative should not need your password or payment PIN. Do not send intimate images or documents because someone says a connection depends on them.',
                    'Avoid putting your home address, daily route, children\'s details, or workplace schedule in a public profile. Share contact details only when you have decided it is appropriate and understand that a recipient can save or forward information you send.'
                ]
            },
            {
                icon: 'handshake',
                title: 'Consent applies at every stage',
                paragraphs: [
                    'A like, match, conversation, payment, or introduction request is not consent to meet, continue messaging, have sex, begin a relationship, or provide financial support. Each person can decline or change their mind without pressure.',
                    'Respect a request to stop contacting someone. Do not use repeated calls, new accounts, threats, or public exposure to force a reply or decision.'
                ]
            },
            {
                icon: 'location_on',
                title: 'Plan a first meeting carefully',
                paragraphs: [
                    'If both people choose to meet, consider a public place, tell a trusted person where you are going, arrange your own transport, and set a check-in time. Keep control of your phone and belongings, and leave if you feel unsafe.',
                    'Do not travel or incur costs because a profile or desk message promises an outcome. Confirm the meeting details with the person directly and avoid sending money for transport, emergencies, or access unless you have independently decided to do so.'
                ]
            },
            {
                icon: 'report',
                title: 'Report an urgent concern',
                paragraphs: [
                    'Use the support and report route for threats, harassment, suspected underage accounts, impersonation, non-consensual images, fraud, or payment instructions that conflict with the app. Include the account name, relevant date, and a concise description. Do not post another person\'s private information as evidence.',
                    'If you face immediate danger, contact local emergency services or a trusted person first. The app is not an emergency-response service, and a report may need staff review before action is taken.'
                ]
            },
            {
                icon: 'child_care',
                title: 'Adults only',
                paragraphs: [
                    'The service is for people aged 18 and over. Do not contact anyone you believe may be under 18, and report an account that appears to belong to a minor. Do not attempt to verify age by requesting private identity documents in member chat.',
                    'If you registered with an incorrect age or believe a minor has accessed the service, stop using the account and contact support so the concern can be reviewed.'
                ]
            }
        ]}
    />;
}
