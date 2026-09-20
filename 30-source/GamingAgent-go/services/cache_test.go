package services

import (
	"testing"
	"time"
)

func TestCacheGetWithinTTL(t *testing.T) {
	c := newCache[string](time.Hour)
	c.set("fresh")
	v, ok := c.get()
	if !ok || v != "fresh" {
		t.Fatalf("get() = %q, %v; want %q, true", v, ok, "fresh")
	}
}

func TestCacheGetExpired(t *testing.T) {
	c := newCache[string](time.Nanosecond)
	c.set("stale")
	time.Sleep(time.Millisecond)
	if v, ok := c.get(); ok {
		t.Fatalf("get() after expiry = %q, true; want ok=false", v)
	}
}

func TestCacheGetNeverSet(t *testing.T) {
	c := newCache[string](time.Hour)
	if v, ok := c.get(); ok {
		t.Fatalf("get() on empty cache = %q, true; want ok=false", v)
	}
}

// This is the exact scenario that was silently broken: a caller checks get()
// first, tries a fresh fetch on a miss, and on fetch failure wants to fall
// back to whatever was last cached — even though it's now past ttl. Before
// getStale() existed, this fell back to get() again, which re-applies the
// ttl check and can never return true here (get() only returns false because
// the cache is expired; nothing changed between the two calls).
func TestCacheStaleFallbackAfterExpiry(t *testing.T) {
	c := newCache[string](time.Nanosecond)
	c.set("last-known-good")
	time.Sleep(time.Millisecond)

	if _, ok := c.get(); ok {
		t.Fatalf("get() should report expired before testing the fallback")
	}
	v, ok := c.getStale()
	if !ok || v != "last-known-good" {
		t.Fatalf("getStale() = %q, %v; want %q, true", v, ok, "last-known-good")
	}
}

func TestCacheGetStaleNeverSet(t *testing.T) {
	c := newCache[string](time.Hour)
	if v, ok := c.getStale(); ok {
		t.Fatalf("getStale() on empty cache = %q, true; want ok=false", v)
	}
}
