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

func (c *cached[T]) get() (T, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if time.Since(c.updatedAt) < c.ttl {
		return c.data, true
	}
	var zero T
	return zero, false
}

func (c *cached[T]) set(v T) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data = v
	c.updatedAt = time.Now()
}
