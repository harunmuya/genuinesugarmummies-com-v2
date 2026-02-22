import { NextResponse } from 'next/server';
import { fetchComments, submitComment } from '@/lib/wordpress';

export async function GET(request) {
    try {
        const { searchParams } = new URL(request.url);
        const postId = searchParams.get('post');

        if (!postId) {
            return NextResponse.json({ error: 'Missing post parameter' }, { status: 400 });
        }

        const comments = await fetchComments(postId);

        return NextResponse.json({ comments }, {
            headers: { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120' },
        });
    } catch (error) {
        console.error('Comments GET error:', error);
        return NextResponse.json({ comments: [] });
    }
}

export async function POST(request) {
    try {
        const body = await request.json();
        const { post_id, author_name, author_email, content } = body;

        if (!post_id || !content) {
            return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
        }

        if (!author_name || author_name.trim().length < 2) {
            return NextResponse.json({ error: 'Name is required (minimum 2 characters)' }, { status: 400 });
        }

        if (!author_email || !author_email.includes('@')) {
            return NextResponse.json({ error: 'Valid email is required' }, { status: 400 });
        }

        const result = await submitComment({
            postId: post_id,
            authorName: author_name.trim(),
            authorEmail: author_email.trim(),
            content: content.trim(),
        });

        if (result.success) {
            return NextResponse.json({
                success: true,
                comment_id: result.comment_id || null,
                message: 'Your comment has been submitted for moderation.',
            });
        } else {
            return NextResponse.json({
                success: false,
                message: result.error || 'Comment submission failed. Please try again.',
            }, { status: 502 });
        }
    } catch (error) {
        console.error('Comments POST error:', error);
        return NextResponse.json({
            success: false,
            message: 'Comment submission failed. Please try again.',
        }, { status: 500 });
    }
}
