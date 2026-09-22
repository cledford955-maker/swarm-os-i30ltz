package services

import (
	"sync"
	"time"
)

type cached[T any] struct {
	mu        sync.RWMutex
	data      T
	updatedAt time.Time
	ttl       time.Duration
}

func newCache[T any](ttl time.Duration) *cached[T] {
	return &cached[T]{ttl: ttl}
}

// get returns the cached value only while it's still within ttl.
func (c *cached[T]) get() (T, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if !c.updatedAt.IsZero() && time.Since(c.updatedAt) < c.ttl {
		return c.data, true
	}
	var zero T
	return zero, false
}

// getStale returns the last cached value regardless of age, for use as a
// fallback when a fresh fetch fails. ok is false only if nothing has ever
// been cached. Callers that check get() first and fall back to getStale()
// on a failed refetch must use this, not get() again — by the time a
// refetch has been attempted, get() has already necessarily expired, so a
// second get() call can never return true.
func (c *cached[T]) getStale() (T, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if c.updatedAt.IsZero() {
		var zero T
		return zero, false
	}
	return c.data, true
}

func (c *cached[T]) set(v T) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = v
	c.updatedAt = time.Now()
}
