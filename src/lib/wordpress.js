// WordPress API — uses the custom GS App API plugin for speed
// Plugin endpoints: /wp-json/gs-app/v1/profiles, /comments/{id}, /comment, /subscribe

const WP_BASE = process.env.NEXT_PUBLIC_WP_API_URL?.replace('/wp/v2', '') || 'https://genuinesugarmummies.com/wp-json';
const GS_API = `${WP_BASE}/gs-app/v1`;
const WP_API = `${WP_BASE}/wp/v2`;

/**
 * Normalize image URLs:
 * 1. Convert Jetpack CDN (i0.wp.com, i1.wp.com, i2.wp.com) to direct WP URLs
 * 2. Force HTTPS
 * 3. Remove problematic query params that break mobile loading
 */
function normalizeImageUrl(url) {
    if (!url) return '';
    try {
        let cleaned = url.trim();
        // Force HTTPS
        if (cleaned.startsWith('http://')) {
            cleaned = cleaned.replace('http://', 'https://');
        }
        // Jetpack CDN URLs (i0.wp.com, i1.wp.com, etc.) are the ACTUAL image servers -
        // do NOT strip them. The direct wp-content/uploads URLs are blocked by the host.
        // Just ensure they're clean and properly formatted.
        return cleaned;
    } catch {
        return url;
    }
}

// Extract first image from HTML content  
function extractImageFromContent(html) {
    if (!html) return '';
    // Try multiple image tag patterns
    const imgMatch = html.match(/<img[^>]+src=["']([^"']+)["'][^>]*>/i);
    if (imgMatch) return normalizeImageUrl(imgMatch[1]);
    // Try srcset as fallback
    const srcsetMatch = html.match(/<img[^>]+srcset=["']([^\s"']+)/i);
    if (srcsetMatch) return normalizeImageUrl(srcsetMatch[1]);
    return '';
}

// Parse profile from WordPress post data
function parseProfile(post) {
    let imageUrl = '';

    // 1. Featured image from _embedded (standard WP REST with _embed)
    if (post._embedded?.['wp:featuredmedia']?.[0]?.source_url) {
        imageUrl = normalizeImageUrl(post._embedded['wp:featuredmedia'][0].source_url);
    }
    // 2. Jetpack featured media URL (available on Jetpack-connected sites)
    else if (post.jetpack_featured_media_url) {
        imageUrl = normalizeImageUrl(post.jetpack_featured_media_url);
    }
    // 3. Featured image URL from custom field (GS plugin)
    else if (post.featured_image_url) {
        imageUrl = normalizeImageUrl(post.featured_image_url);
    }
    // 4. Image URL from GS plugin
    else if (post.image_url) {
        imageUrl = normalizeImageUrl(post.image_url);
    }
    // 5. OG image from Yoast SEO
    else if (post.yoast_head_json?.og_image?.[0]?.url) {
        imageUrl = normalizeImageUrl(post.yoast_head_json.og_image[0].url);
    }
    // 6. Extract from content HTML
    else if (post.content?.rendered) {
        imageUrl = extractImageFromContent(post.content.rendered);
    }
    // 7. Extract from excerpt HTML
    else if (post.excerpt?.rendered) {
        imageUrl = extractImageFromContent(post.excerpt.rendered);
    }

    // Parse text content
    const titleText = post.title?.rendered
        ? post.title.rendered.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#8217;/g, "'").replace(/&#8211;/g, '-').replace(/&nbsp;/g, ' ')
        : 'Sugar Mummy';
    const excerptText = post.excerpt?.rendered
        ? post.excerpt.rendered.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&#8217;/g, "'").replace(/&#8211;/g, '-').replace(/&nbsp;/g, ' ').replace(/&hellip;/g, '...').trim()
        : '';
    const contentHtml = post.content?.rendered || '';

    // Extract location
    const locationMatch = titleText.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i)
        || excerptText.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i);
    const location = locationMatch ? locationMatch[1] : '';

    // Extract age
    const ageMatch = titleText.match(/(\d{2})\s*(?:years|yrs|year)/i)
        || titleText.match(/age[d]?\s*(\d{2})/i)
        || excerptText.match(/(\d{2})\s*(?:years|yrs|year)/i);
    const age = ageMatch ? parseInt(ageMatch[1]) : null;

    // Extract name
    let name = titleText;
    name = name
        .replace(/sugar\s*mumm(?:y|ies)/gi, '')
        .replace(/looking\s+for\s+.*/gi, '')
        .replace(/\s+in\s+[A-Z].*/i, '')
        .replace(/\s+from\s+[A-Z].*/i, '')
        .replace(/\s+aged?\s+\d+.*/i, '')
        .replace(/\d{2}\s*(?:years|yrs).*/i, '')
        .replace(/needs?\s+.*/gi, '')
        .replace(/wants?\s+.*/gi, '')
        .replace(/[–—-]\s*.*/g, '')
        .trim();
    if (!name || name.length < 2) name = titleText.split(/[–—-]/)[0].trim();
    if (!name || name.length < 2) name = 'Sugar Mummy';

    const postDate = new Date(post.date || post.date_gmt);
    const now = new Date();
    const daysSincePost = Math.max(0, Math.floor((now - postDate) / (1000 * 60 * 60 * 24)));

    const coords = (post.latitude && post.longitude)
        ? { latitude: parseFloat(post.latitude), longitude: parseFloat(post.longitude) }
        : null;

    return {
        wpId: post.id,
        name: name.substring(0, 40),
        age,
        location,
        bio: excerptText.substring(0, 300),
        excerpt: excerptText.substring(0, 200),
        content: contentHtml,
        imageUrl,
        link: post.link || '',
        date: post.date,
        commentCount: post.comment_count ?? post._embedded?.replies?.[0]?.length ?? 0,
        daysSincePost,
        coords,
        slug: post.slug,
    };
}

// Strip HTML entities and tags from a string
function cleanText(str) {
    if (!str) return '';
    return str
        .replace(/<[^>]+>/g, '')
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')
        .replace(/&#8217;/g, "'")
        .replace(/&#8220;/g, '"')
        .replace(/&#8221;/g, '"')
        .replace(/&#8211;/g, '-')
        .replace(/&#8230;/g, '...')
        .replace(/&hellip;/g, '...')
        .replace(/&nbsp;/g, ' ')
        .trim();
}

// Extract person name from a post title (e.g. "Genevieve Sugar Mummy Mombasa" → "Genevieve")
function extractNameFromTitle(rawTitle) {
    const title = cleanText(rawTitle);
    let name = title
        .replace(/sugar\s*mumm(?:y|ies)/gi, '')
        .replace(/looking\s+for\s+.*/gi, '')
        .replace(/\s+in\s+[A-Z].*/i, '')
        .replace(/\s+from\s+[A-Z].*/i, '')
        .replace(/\s+aged?\s+\d+.*/i, '')
        .replace(/\d{2}\s*(?:years|yrs).*/i, '')
        .replace(/needs?\s+.*/gi, '')
        .replace(/wants?\s+.*/gi, '')
        .replace(/is\s+.*/gi, '')
        .replace(/[–—-]\s*.*/g, '')
        .trim();
    if (!name || name.length < 2) name = title.split(/[–—-]/)[0].trim();
    if (!name || name.length < 2) name = 'Sugar Mummy';
    return name.substring(0, 40);
}

// ---- Fetch profiles (paginated) ----
export async function fetchProfiles(page = 1, perPage = 25) {
    try {
        // Try custom GS API first (faster, built for this)
        const gsRes = await fetch(`${GS_API}/profiles?page=${page}&per_page=${perPage}`, {
            next: { revalidate: 300 },
        });

        if (gsRes.ok) {
            const data = await gsRes.json();
            if (data.profiles) {
                const now = new Date();
                const profiles = data.profiles.map(p => {
                    const titleClean = cleanText(p.title || '');
                    const excerptClean = cleanText(p.excerpt || '').substring(0, 300);

                    // Extract location from title or excerpt
                    const locationMatch =
                        titleClean.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i) ||
                        excerptClean.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i);

                    // Extract age
                    const ageMatch =
                        titleClean.match(/(\d{2})\s*(?:years|yrs|year)/i) ||
                        excerptClean.match(/(\d{2})\s*(?:years|yrs|year)/i);

                    const postDate = new Date(p.date || Date.now());
                    const daysSincePost = Math.max(0, Math.floor((now - postDate) / (1000 * 60 * 60 * 24)));

                    return {
                        wpId: p.wpId || p.id,
                        name: extractNameFromTitle(p.title || ''),
                        age: ageMatch ? parseInt(ageMatch[1]) : null,
                        location: locationMatch ? locationMatch[1] : '',
                        bio: excerptClean,
                        excerpt: excerptClean.substring(0, 200),
                        content: p.content || '',
                        // Keep Jetpack CDN URLs intact — they ARE the image server
                        imageUrl: normalizeImageUrl(p.imageUrl || p.image_url || p.featured_image_url || ''),
                        link: p.link || '',
                        date: p.date || '',
                        commentCount: p.commentCount ?? p.comment_count ?? 0,
                        daysSincePost,
                        coords: (p.latitude && p.longitude)
                            ? { latitude: parseFloat(p.latitude), longitude: parseFloat(p.longitude) }
                            : null,
                        slug: p.slug || '',
                    };
                });
                return {
                    profiles,
                    // GS API returns totalPages (camelCase) — also check snake_case fallback
                    totalPages: data.totalPages || data.total_pages || Math.ceil((data.totalPosts || data.total || profiles.length) / perPage) || 1,
                    totalPosts: data.totalPosts || data.total || profiles.length,
                };
            }
            // .com GS API returns array at root with pagination keys: { [0]: {...}, total, total_pages }
            // We need to extract the array items and pagination separately
            if (Array.isArray(data) || (data && typeof data === 'object' && !data.profiles)) {
                const now = new Date();
                const items = Array.isArray(data) ? data : (data.data || []);
                const totalCount = data.total || items.length;
                const totalPagesCount = data.total_pages || data.totalPages || Math.ceil(totalCount / perPage) || 1;

                const profiles = items.filter(p => p && (p.id || p.wpId)).map(p => {
                    const titleClean = cleanText(p.title || '');
                    const excerptClean = cleanText(p.excerpt || '').substring(0, 300);
                    const locationMatch =
                        titleClean.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i) ||
                        excerptClean.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i);
                    const ageMatch =
                        titleClean.match(/(\d{2})\s*(?:years|yrs|year)/i) ||
                        excerptClean.match(/(\d{2})\s*(?:years|yrs|year)/i);
                    const postDate = new Date(p.date || Date.now());
                    const daysSincePost = Math.max(0, Math.floor((now - postDate) / (1000 * 60 * 60 * 24)));
                    return {
                        wpId: p.wpId || p.id,
                        name: extractNameFromTitle(p.title || ''),
                        age: ageMatch ? parseInt(ageMatch[1]) : null,
                        location: locationMatch ? locationMatch[1] : '',
                        bio: excerptClean,
                        excerpt: excerptClean.substring(0, 200),
                        content: p.content || '',
                        imageUrl: normalizeImageUrl(p.imageUrl || p.image_url || p.featured_image_url || ''),
                        link: p.link || '',
                        date: p.date || '',
                        commentCount: p.commentCount ?? p.comment_count ?? 0,
                        daysSincePost,
                        coords: (p.latitude && p.longitude) ? { latitude: parseFloat(p.latitude), longitude: parseFloat(p.longitude) } : null,
                        slug: p.slug || '',
                    };
                });
                return { profiles, totalPages: totalPagesCount, totalPosts: totalCount };
            }
        }
    } catch (err) {
        console.error('GS API failed, trying WP API:', err.message);
    }

    // Fallback to standard WP REST API
    try {
        const wpRes = await fetch(
            `${WP_API}/posts?page=${page}&per_page=${perPage}&_embed&orderby=date&order=desc`,
            { next: { revalidate: 300 } }
        );

        if (!wpRes.ok) {
            return { profiles: [], totalPages: 0, totalPosts: 0 };
        }

        const posts = await wpRes.json();
        const totalPages = parseInt(wpRes.headers.get('X-WP-TotalPages') || '1');
        const totalPosts = parseInt(wpRes.headers.get('X-WP-Total') || String(posts.length));
        const profiles = posts.map(parseProfile);
        return { profiles, totalPages, totalPosts };
    } catch (err) {
        console.error('WP API also failed:', err.message);
        return { profiles: [], totalPages: 0, totalPosts: 0 };
    }
}

// ---- Fetch single profile ----
export async function fetchSingleProfile(id) {
    try {
        const gsRes = await fetch(`${GS_API}/profiles/${id}`, {
            next: { revalidate: 120 },
        });

        if (gsRes.ok) {
            const data = await gsRes.json();
            // GS API returns flat format: { id/wpId, title (string), excerpt (string), imageUrl, ... }
            if (data.id || data.wpId) {
                const titleClean = cleanText(data.title || '');
                const excerptClean = cleanText(data.excerpt || '');
                const locationMatch =
                    titleClean.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i) ||
                    excerptClean.match(/(?:in|from|based in|located in|living in)\s+([A-Z][a-z]+(?:\s[A-Z][a-z]+)?)/i);
                const ageMatch =
                    titleClean.match(/(\d{2})\s*(?:years|yrs|year)/i) ||
                    excerptClean.match(/(\d{2})\s*(?:years|yrs|year)/i);
                const postDate = new Date(data.date || Date.now());
                const daysSincePost = Math.max(0, Math.floor((new Date() - postDate) / (1000 * 60 * 60 * 24)));
                return {
                    wpId: data.wpId || data.id,
                    name: extractNameFromTitle(data.title || ''),
                    age: ageMatch ? parseInt(ageMatch[1]) : null,
                    location: locationMatch ? locationMatch[1] : '',
                    bio: excerptClean.substring(0, 300),
                    excerpt: excerptClean.substring(0, 200),
                    content: data.content || '',
                    imageUrl: normalizeImageUrl(data.imageUrl || data.image_url || data.featured_image_url || ''),
                    link: data.link || '',
                    date: data.date || '',
                    commentCount: data.commentCount ?? data.comment_count ?? 0,
                    daysSincePost,
                    coords: null,
                    slug: data.slug || '',
                };
            }
        }
    } catch (err) {
        console.error('GS single profile error:', err.message);
    }

    try {
        const wpRes = await fetch(`${WP_API}/posts/${id}?_embed`, {
            next: { revalidate: 120 },
        });
        if (!wpRes.ok) return null;
        const post = await wpRes.json();
        return parseProfile(post);
    } catch {
        return null;
    }
}

// ---- Fetch comments for a post (with avatars) ----
export async function fetchComments(postId) {
    try {
        const gsRes = await fetch(`${GS_API}/comments/${postId}`, {
            next: { revalidate: 60 },
        });

        if (gsRes.ok) {
            const data = await gsRes.json();
            if (Array.isArray(data)) {
                return data.map(c => ({
                    id: c.id,
                    author_name: c.author_name || c.author || 'Anonymous',
                    avatar_url: normalizeImageUrl(c.author_avatar_url || c.avatar_url || ''),
                    content: c.content?.rendered || c.content || '',
                    date: c.date || c.date_gmt,
                }));
            }
        }
    } catch { }

    // Fallback to WP API
    try {
        const wpRes = await fetch(
            `${WP_API}/comments?post=${postId}&per_page=50&order=desc&orderby=date`,
            { next: { revalidate: 60 } }
        );
        if (!wpRes.ok) return [];
        const comments = await wpRes.json();

        return comments.map(c => ({
            id: c.id,
            author_name: c.author_name || 'Anonymous',
            avatar_url: normalizeImageUrl(
                c.author_avatar_urls?.['96'] || c.author_avatar_urls?.['48'] || ''
            ),
            content: c.content?.rendered || '',
            date: c.date,
        }));
    } catch {
        return [];
    }
}

// ---- Submit a comment (requires logged-in user) ----
export async function submitComment({ postId, authorName, authorEmail, content }) {
    // Try GS App plugin endpoint first
    try {
        console.log(`[Comment Submit] Trying GS API: ${GS_API}/comment for post ${postId}`);
        const gsRes = await fetch(`${GS_API}/comment`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                post_id: postId,
                author_name: authorName,
                author_email: authorEmail,
                content,
            }),
        });

        console.log(`[Comment Submit] GS API response: ${gsRes.status}`);
        if (gsRes.ok) {
            const data = await gsRes.json();
            console.log(`[Comment Submit] GS API success:`, data);
            return { success: true, comment_id: data.comment_id || data.id || null };
        } else {
            const errText = await gsRes.text().catch(() => 'unknown');
            console.error(`[Comment Submit] GS API failed: ${gsRes.status} - ${errText}`);
        }
    } catch (err) {
        console.error(`[Comment Submit] GS API error:`, err.message);
    }

    // Fallback to standard WP comments API
    try {
        console.log(`[Comment Submit] Trying WP API: ${WP_API}/comments`);
        const wpRes = await fetch(`${WP_API}/comments`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                post: parseInt(postId),
                author_name: authorName,
                author_email: authorEmail,
                content,
            }),
        });

        console.log(`[Comment Submit] WP API response: ${wpRes.status}`);
        if (wpRes.ok) {
            const data = await wpRes.json();
            return { success: true, comment_id: data.id };
        } else {
            const errText = await wpRes.text().catch(() => 'unknown');
            console.error(`[Comment Submit] WP API failed: ${wpRes.status} - ${errText}`);
        }
    } catch (err) {
        console.error(`[Comment Submit] WP API error:`, err.message);
    }

    // Both endpoints failed
    console.error('[Comment Submit] All endpoints failed for post', postId);
    return { success: false, comment_id: null, error: 'Comment submission failed. Please try again.' };
}
