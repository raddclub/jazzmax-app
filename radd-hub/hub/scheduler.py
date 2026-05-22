"""Background scheduler for recurring tasks (Ongoing series rescan, etc.)."""
import logging
import threading
import time
from . import db, scraper, config, downloader

log = logging.getLogger("hub.scheduler")

def rescan_ongoing_titles(log_fn=None):
    """Find titles marked as 'ongoing' and check for new episodes."""
    def _log(msg):
        if log_fn: log_fn(msg)
        log.info(msg)

    _log("Starting scheduled rescan of ongoing titles...")
    
    with db.conn() as c:
        # We look for titles that have 'ongoing' status
        ongoing_titles = c.execute(
            "SELECT id, title, year, status FROM titles WHERE status = 'ongoing'"
        ).fetchall()

    if not ongoing_titles:
        _log("No ongoing titles found to rescan.")
        return

    for t in ongoing_titles:
        _log(f"Checking for new episodes of '{t['title']}'...")
        
        # 1. Count existing episodes
        with db.conn() as c:
            existing_count = c.execute(
                "SELECT COUNT(*) as count FROM files WHERE title_id = ?", (t['id'],)
            ).fetchone()['count']
        
        # 2. Trigger a fresh scrape (AI mode will use cache if possible, but we want to be smart)
        # We create a mock job for the scraper
        job_id = f"rescan-{t['id']}-{int(time.time())}"
        movie_query = t['title']
        if t['year']:
            movie_query += f" ({t['year']})"
            
        mock_job = {
            "job_id": job_id,
            "movie": movie_query,
            "movie_clean": t['title'],
            "year_hint": t['year'],
            "status": "processing",
            "pause_event": threading.Event(),
            "cancel_event": threading.Event(),
        }
        mock_job["pause_event"].set()
        
        # Load config
        sc_config = {
            "auto_download": False, # We handle queuing ourselves
            "quality": db.setting("preferred_quality", "1080p") or "1080p",
            "language": db.setting("preferred_language", "Hindi") or "Hindi",
        }
        
        try:
            # We use scraper.run_job_ai to find links
            # Note: We need to modify run_job_ai to return links or store them in job
            scraper.run_job_ai(mock_job, sc_config, _log)
            
            result_url = mock_job.get("result_url")
            if result_url:
                links = result_url.split("||")
                new_links = []
                
                # Simple logic: if site has more links than we have files, 
                # we assume new episodes are available.
                # A more robust logic would compare filenames/episode numbers.
                if len(links) > existing_count:
                    _log(f"Found {len(links)} episodes on site, we have {existing_count}. Queuing new ones...")
                    # For now, let's just queue the links we don't have.
                    # This is tricky because we don't know which link is which episode without downloading.
                    # Strategy: If it's ongoing, we usually download individual episodes.
                    # If len(links) == 4 and we have 3, we download links[3] (index 3).
                    new_links = links[existing_count:]
                    
                    for link in new_links:
                        db.add_to_queue(
                            movie=movie_query,
                            url=link,
                            site=mock_job.get("site_used", "auto"),
                            status="queued",
                            message="Auto-queued by daily rescan"
                        )
                        _log(f"Queued new episode link: {link[:50]}...")
                else:
                    _log(f"No new episodes found for '{t['title']}'.")
            
        except Exception as e:
            _log(f"Error rescanning '{t['title']}': {e}")

def scheduler_loop(stop_event: threading.Event):
    """Background loop that runs every 24 hours."""
    # Wait 5 minutes after startup before first rescan to let system settle
    if stop_event.wait(300):
        return

    while not stop_event.is_set():
        try:
            rescan_ongoing_titles()
        except Exception as e:
            log.error("Scheduler loop error: %s", e)
        
        # Wait 24 hours
        if stop_event.wait(24 * 3600):
            break

def start(stop_event: threading.Event):
    """Start the scheduler thread."""
    t = threading.Thread(target=scheduler_loop, args=(stop_event,), daemon=True, name="hub-scheduler")
    t.start()
    log.info("Background scheduler started (24h interval)")
