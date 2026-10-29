import PolicyDocument from '@/components/PolicyDocument';

export const metadata = { title: 'Community Guidelines - Genuine Sugarmummies' };

export default function CommunityGuidelinesPage() {
    return <PolicyDocument
        title="Community Guidelines"
        eyebrow="How members are expected to treat one another"
        icon="groups"
        summary="These guidelines apply to profiles, direct messages, calls, comments, payment discussions, and introductions. The aim is a service where adults can make their own choices without deception, pressure, or misuse of private information."
        sections={[
            {
                icon: 'person_check',
                title: 'Use the service only as an adult',
                paragraphs: [
                    'You must be 18 or older. Do not create, request, or maintain an account for a minor, and do not contact someone you believe may be under 18. Report a suspected underage account through support.',
                    'Do not use the app to arrange illegal activity, exploit another person, or evade a safety restriction. The desk may pause an account while checking a serious concern.'
                ]
            },
            {
                icon: 'account_circle',
                title: 'Represent yourself honestly',
                paragraphs: [
                    'Use profile details that are accurate to the best of your knowledge. Do not impersonate a real person, claim to be an employee, create multiple accounts to evade a restriction, or misrepresent what the desk has confirmed.',
                    'A review or badge is limited to the review step described by the service. Do not present it as a guarantee of identity, image origin, safety, availability, or a future outcome.'
                ]
            },
            {
                icon: 'image',
                title: 'Share images and writing you may use',
                paragraphs: [
                    'Upload only photographs and writing that you created or have permission to share. Do not take images from another member, social account, or private conversation and pass them off as your own.',
                    'Do not upload intimate material without the subject\'s informed permission. Do not threaten to publish, forward, or sell private images or conversations.'
                ]
            },
            {
                icon: 'favorite',
                title: 'Respect consent and boundaries',
                paragraphs: [
                    'A profile view, like, match, payment, or reply is not permission to continue contacting someone, arrange a meeting, have sex, begin a relationship, or provide money. Ask clearly, accept a no, and stop when someone asks you to stop.',
                    'Do not pressure a member to meet, disclose private details, send images, or make a financial decision. Consent must be voluntary and can be withdrawn.'
                ]
            },
            {
                icon: 'block',
                title: 'No harassment, threats, or exploitation',
                paragraphs: [
                    'Threats, stalking, repeated unwanted contact, hate, humiliation, blackmail, extortion, coercion, and sexual exploitation are not allowed. Do not use insults or personal information to intimidate a member into responding.',
                    'Scams, impersonation, spam, phishing, requests for passwords or payment PINs, and misleading payment instructions are prohibited. Never claim that a fee can buy affection, consent, or guaranteed financial support.'
                ]
            },
            {
                icon: 'privacy_tip',
                title: 'Keep other people\'s information private',
                paragraphs: [
                    'Do not publish another person\'s phone number, address, workplace, identity document, private message, or intimate image without their permission. Do not collect or share information to embarrass, threaten, or track a member.',
                    'If a report needs supporting information, send only what is relevant through the support route. Avoid posting screenshots publicly; they can expose people who are not involved in the dispute.'
                ]
            },
            {
                icon: 'report',
                title: 'Report problems; do not retaliate',
                paragraphs: [
                    'Report suspected fraud, impersonation, underage accounts, harassment, threats, or non-consensual images using the support route. Include enough context for the desk to understand the concern, but do not send passwords or payment PINs.',
                    'The desk may review the content, request additional context, hide a profile, or restrict features while reviewing a report. A report does not guarantee a particular decision or response time. Do not threaten or harass someone because you reported them or they reported you.'
                ]
            },
            {
                icon: 'admin_panel_settings',
                title: 'How moderation works',
                paragraphs: [
                    'Moderation may consider the information available in a profile, message, report, or payment request. The desk may remove content or restrict an account where necessary to address safety, fraud, or repeated guideline violations.',
                    'If you believe an action was mistaken, contact support with the account email and a clear explanation. Do not create a replacement account to bypass an active review.'
                ]
            }
        ]}
    />;
}
