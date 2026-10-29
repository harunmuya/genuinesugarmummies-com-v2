const PROFILE_TYPES = new Set(['sugar_mummy', 'sugar_daddy', 'mistress', 'toyboy']);

export function userProfileLabel(user) {
    const label = String(
        user?.profile_label || user?.profileLabel || user?.member_category || user?.memberCategory || '',
    ).toLowerCase();
    if (PROFILE_TYPES.has(label)) return label;

    const preference = String(user?.preference || '').toLowerCase();
    const ownType = preference.split('_looking_for_')[0];
    if (PROFILE_TYPES.has(ownType)) return ownType;
    return '';
}

export function targetLabelsForUser(user) {
    const targets = {
        sugar_mummy: ['toyboy'],
        toyboy: ['sugar_mummy'],
        sugar_daddy: ['mistress'],
        mistress: ['sugar_daddy'],
    };
    const requested = String(user?.looking_for || user?.lookingFor || '').toLowerCase();
    if (requested) {
        if (requested.includes('mummy')) return new Set(['sugar_mummy']);
        if (requested.includes('daddy')) return new Set(['sugar_daddy']);
        if (requested.includes('mistress')) return new Set(['mistress']);
        if (requested.includes('toyboy') || requested.includes('sugar guy') || requested.includes('sugar boy')) return new Set(['toyboy']);
    }
    const label = userProfileLabel(user);
    return targets[label] ? new Set(targets[label]) : null;
}

export function profileFitsUser(member, user) {
    const targets = targetLabelsForUser(user);
    if (!targets) return true;
    return targets.has(String(member?.profileLabel || member?.profile_label || member?.memberCategory || member?.member_category || '').toLowerCase());
}
