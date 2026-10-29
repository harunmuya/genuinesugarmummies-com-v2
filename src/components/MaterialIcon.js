export default function MaterialIcon({ name, className = '' }) {
    const iconName = /^[a-z0-9_]+$/.test(name || '') ? name : 'info';

    return (
        <span
            aria-hidden="true"
            className={`material-icon ${className}`.trim()}
            style={{ '--material-icon-url': `url("/material-symbols/outlined/${iconName}.svg")` }}
        >
            <span className="material-icon__glyph" />
        </span>
    );
}
