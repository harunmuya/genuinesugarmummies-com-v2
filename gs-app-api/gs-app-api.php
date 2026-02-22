<?php
/**
 * Plugin Name:  GS App API
 * Plugin URI:   https://genuinesugarmummies.com
 * Description:  Multi-purpose REST API plugin for the GenuineSugarMummies.com Next.js app.
 *               Handles profiles/posts, comments (with avatars), featured images, and email subscriptions.
 * Version:      2.0.0
 * Author:       GenuineSugarMummies.com
 * Author URI:   https://genuinesugarmummies.com
 * License:      GPL2
 * Text Domain:  gs-app-api
 *
 * ENDPOINTS:
 *   GET  /wp-json/gs-app/v1/profiles          — paginated profile/post list with images
 *   GET  /wp-json/gs-app/v1/profiles/{id}     — single profile/post with image
 *   GET  /wp-json/gs-app/v1/comments/{post_id}— comments with author avatars
 *   POST /wp-json/gs-app/v1/comment           — submit comment (held for moderation)
 *   POST /wp-json/gs-app/v1/subscribe         — email subscription
 */

if (!defined('ABSPATH')) exit;

// =========================================================================
// CORS — allow the .com app to call this API
// =========================================================================
add_action('rest_api_init', function () {
    remove_filter('rest_pre_serve_request', 'rest_send_cors_headers');
    add_filter('rest_pre_serve_request', function ($value) {
        $allowed = [
            'https://genuinesugarmummies.com',
            'https://www.genuinesugarmummies.com',
            'http://localhost:3000',
            'http://localhost:3001',
        ];
        $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
        if (in_array($origin, $allowed, true)) {
            header("Access-Control-Allow-Origin: {$origin}");
        }
        header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization');
        header('Access-Control-Allow-Credentials: true');
        return $value;
    });
});

// =========================================================================
// Register all REST routes
// =========================================================================
add_action('rest_api_init', function () {

    $ns = 'gs-app/v1';

    // ---- Profiles (GET list) ----
    register_rest_route($ns, '/profiles', [
        'methods'  => 'GET',
        'callback' => 'gs_api_get_profiles',
        'permission_callback' => '__return_true',
    ]);

    // ---- Single Profile (GET by ID) ----
    register_rest_route($ns, '/profiles/(?P<id>\d+)', [
        'methods'  => 'GET',
        'callback' => 'gs_api_get_single_profile',
        'permission_callback' => '__return_true',
    ]);

    // ---- Comments for post (GET) ----
    register_rest_route($ns, '/comments/(?P<post_id>\d+)', [
        'methods'  => 'GET',
        'callback' => 'gs_api_get_comments',
        'permission_callback' => '__return_true',
    ]);

    // ---- Submit comment (POST) ----
    register_rest_route($ns, '/comment', [
        'methods'  => 'POST',
        'callback' => 'gs_api_submit_comment',
        'permission_callback' => '__return_true',
    ]);

    // ---- Subscribe (POST) ----
    register_rest_route($ns, '/subscribe', [
        'methods'  => 'POST',
        'callback' => 'gs_api_subscribe',
        'permission_callback' => '__return_true',
    ]);
});

// =========================================================================
// HELPER: Build a profile object from a WP_Post
// =========================================================================
function gs_api_build_profile($post) {
    $post_id = $post->ID;

    // ---- Featured image (multiple fallbacks) ----
    $image_url = '';

    // 1. WordPress featured image (thumbnail)
    $thumb_id = get_post_thumbnail_id($post_id);
    if ($thumb_id) {
        $img = wp_get_attachment_image_src($thumb_id, 'large');
        if ($img && !empty($img[0])) {
            $image_url = $img[0];
        }
    }

    // 2. First image from post content
    if (empty($image_url)) {
        $content = $post->post_content;
        if (preg_match('/<img[^>]+src=["\']([^"\']+)["\']/i', $content, $m)) {
            $image_url = $m[1];
        }
    }

    // 3. First attached image
    if (empty($image_url)) {
        $attachments = get_posts([
            'post_parent'    => $post_id,
            'post_type'      => 'attachment',
            'post_mime_type' => 'image',
            'posts_per_page' => 1,
            'orderby'        => 'menu_order',
            'order'          => 'ASC',
        ]);
        if (!empty($attachments)) {
            $image_url = wp_get_attachment_url($attachments[0]->ID);
        }
    }

    // Force to full URL
    if (!empty($image_url) && strpos($image_url, '//') === false) {
        $image_url = home_url($image_url);
    }

    // Get excerpt
    $excerpt = $post->post_excerpt;
    if (empty($excerpt)) {
        $excerpt = wp_trim_words(wp_strip_all_tags($post->post_content), 40, '...');
    }

    // Comment count
    $comment_count = (int) get_comments_number($post_id);

    // Tags
    $tags = wp_get_post_tags($post_id, ['fields' => 'names']);

    return [
        'id'                 => $post_id,
        'title'              => get_the_title($post_id),
        'slug'               => $post->post_name,
        'excerpt'            => $excerpt,
        'content'            => apply_filters('the_content', $post->post_content),
        'date'               => $post->post_date,
        'date_gmt'           => $post->post_date_gmt,
        'link'               => get_permalink($post_id),
        'image_url'          => $image_url,
        'featured_image_url' => $image_url,
        'imageUrl'           => $image_url,
        'comment_count'      => $comment_count,
        'tags'               => $tags,
    ];
}

// =========================================================================
// GET /profiles — paginated list with images
// =========================================================================
function gs_api_get_profiles(WP_REST_Request $request) {
    $page     = max(1, (int) $request->get_param('page'));
    $per_page = min(100, max(1, (int) ($request->get_param('per_page') ?: 25)));

    $query = new WP_Query([
        'post_type'      => 'post',
        'post_status'    => 'publish',
        'paged'          => $page,
        'posts_per_page' => $per_page,
        'orderby'        => 'date',
        'order'          => 'DESC',
    ]);

    $profiles = [];
    foreach ($query->posts as $post) {
        $profiles[] = gs_api_build_profile($post);
    }

    return new WP_REST_Response([
        'profiles'    => $profiles,
        'total'       => (int) $query->found_posts,
        'total_pages' => (int) $query->max_num_pages,
        'page'        => $page,
        'per_page'    => $per_page,
    ], 200);
}

// =========================================================================
// GET /profiles/{id} — single profile with full content + image
// =========================================================================
function gs_api_get_single_profile(WP_REST_Request $request) {
    $post_id = (int) $request->get_param('id');
    $post    = get_post($post_id);

    if (!$post || $post->post_status !== 'publish') {
        return new WP_REST_Response(['error' => 'Profile not found'], 404);
    }

    return new WP_REST_Response(gs_api_build_profile($post), 200);
}

// =========================================================================
// GET /comments/{post_id} — comments with author avatars
// =========================================================================
function gs_api_get_comments(WP_REST_Request $request) {
    $post_id  = (int) $request->get_param('post_id');
    $comments = get_comments([
        'post_id' => $post_id,
        'status'  => 'approve',
        'number'  => 50,
        'orderby' => 'comment_date',
        'order'   => 'DESC',
    ]);

    $result = [];
    foreach ($comments as $c) {
        // Get avatar URL (Gravatar or WP user avatar)
        $avatar_url = get_avatar_url($c->comment_author_email, [
            'size'    => 96,
            'default' => 'mystery',
        ]);

        $result[] = [
            'id'                => (int) $c->comment_ID,
            'author_name'       => $c->comment_author ?: 'Anonymous',
            'author_avatar_url' => $avatar_url ?: '',
            'avatar_url'        => $avatar_url ?: '',
            'content'           => $c->comment_content,
            'date'              => $c->comment_date,
            'date_gmt'          => $c->comment_date_gmt,
        ];
    }

    return new WP_REST_Response($result, 200);
}

// =========================================================================
// POST /comment — submit a comment (held for moderation)
// =========================================================================
function gs_api_submit_comment(WP_REST_Request $request) {
    $params = $request->get_json_params();

    $post_id      = isset($params['post_id']) ? (int) $params['post_id'] : 0;
    $author_name  = sanitize_text_field($params['author_name'] ?? '');
    $author_email = sanitize_email($params['author_email'] ?? '');
    $content      = sanitize_textarea_field($params['content'] ?? '');

    if (!$post_id || empty($content)) {
        return new WP_REST_Response(['error' => 'Missing post_id or content'], 400);
    }

    if (empty($author_name) || strlen($author_name) < 2) {
        return new WP_REST_Response(['error' => 'Author name is required (min 2 chars)'], 400);
    }

    if (empty($author_email) || !is_email($author_email)) {
        return new WP_REST_Response(['error' => 'Valid email is required'], 400);
    }

    // Check post exists
    $post = get_post($post_id);
    if (!$post || $post->post_status !== 'publish') {
        return new WP_REST_Response(['error' => 'Post not found'], 404);
    }

    // Insert comment — held for moderation (status = 0)
    $comment_id = wp_insert_comment([
        'comment_post_ID'      => $post_id,
        'comment_author'       => $author_name,
        'comment_author_email' => $author_email,
        'comment_content'      => $content,
        'comment_approved'     => 0,
        'comment_type'         => 'comment',
        'comment_agent'        => 'GS-App/2.0 (genuinesugarmummies.com)',
        'comment_author_IP'    => $_SERVER['REMOTE_ADDR'] ?? '',
    ]);

    if (!$comment_id || is_wp_error($comment_id)) {
        return new WP_REST_Response([
            'success' => false,
            'error'   => 'Failed to submit comment',
        ], 500);
    }

    return new WP_REST_Response([
        'success'    => true,
        'comment_id' => $comment_id,
        'message'    => 'Comment submitted for moderation',
    ], 201);
}

// =========================================================================
// POST /subscribe — email subscription
// =========================================================================
function gs_api_subscribe(WP_REST_Request $request) {
    $params = $request->get_json_params();

    $email       = sanitize_email($params['email'] ?? '');
    $name        = sanitize_text_field($params['name'] ?? '');
    $is_verified = !empty($params['is_verified']);
    $source      = sanitize_text_field($params['source'] ?? 'genuinesugarmummies.com');

    if (empty($email) || !is_email($email)) {
        return new WP_REST_Response(['error' => 'Valid email required'], 400);
    }

    // Store in options table
    $subs = get_option('gs_app_subscribers', []);

    // Check duplicate
    foreach ($subs as $sub) {
        if ($sub['email'] === $email) {
            return new WP_REST_Response([
                'success' => true,
                'message' => 'You are already subscribed!',
            ], 200);
        }
    }

    $subs[] = [
        'email'       => $email,
        'name'        => $name,
        'is_verified' => $is_verified,
        'source'      => $source,
        'date'        => current_time('mysql'),
        'ip'          => $_SERVER['REMOTE_ADDR'] ?? '',
    ];

    update_option('gs_app_subscribers', $subs);

    // Notify admin
    $admin_email = get_option('admin_email');
    $subject     = "[GS App] New Subscriber: {$email}";
    $body        = "New subscriber from {$source}:\n\nEmail: {$email}\nName: {$name}\nVerified: " . ($is_verified ? 'Yes' : 'No') . "\nDate: " . current_time('mysql');
    wp_mail($admin_email, $subject, $body);

    return new WP_REST_Response([
        'success' => true,
        'message' => 'Subscribed! You will receive new profile alerts.',
    ], 201);
}

// =========================================================================
// Admin page: View subscribers
// =========================================================================
add_action('admin_menu', function () {
    add_submenu_page(
        'tools.php',
        'GS App Subscribers',
        'GS App Subscribers',
        'manage_options',
        'gs-app-subscribers',
        'gs_app_subscribers_page'
    );
});

function gs_app_subscribers_page() {
    $subs = get_option('gs_app_subscribers', []);
    echo '<div class="wrap"><h1>GS App Subscribers (' . count($subs) . ')</h1>';
    echo '<table class="widefat striped"><thead><tr>';
    echo '<th>Email</th><th>Name</th><th>Source</th><th>Verified</th><th>Date</th>';
    echo '</tr></thead><tbody>';
    foreach (array_reverse($subs) as $s) {
        echo '<tr>';
        echo '<td>' . esc_html($s['email']) . '</td>';
        echo '<td>' . esc_html($s['name'] ?? '') . '</td>';
        echo '<td>' . esc_html($s['source'] ?? '') . '</td>';
        echo '<td>' . ($s['is_verified'] ? '✅' : '—') . '</td>';
        echo '<td>' . esc_html($s['date'] ?? '') . '</td>';
        echo '</tr>';
    }
    echo '</tbody></table></div>';
}

// =========================================================================
// Force all comments from this plugin to start as held for moderation
// =========================================================================
add_filter('pre_comment_approved', function ($approved, $commentdata) {
    if (strpos($commentdata['comment_agent'] ?? '', 'GS-App') !== false) {
        return 0;
    }
    return $approved;
}, 10, 2);
