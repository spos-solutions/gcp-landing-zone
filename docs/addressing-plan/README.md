# IP Addressing Plan

This directory contains documentation for the IP addressing scheme used across the GCP landing zone.

## Purpose

Track and document:
- Subnet allocations per environment
- IP address ranges
- CIDR blocks
- Network segmentation

## Structure

Document subnet allocations as they are created for:
- Development environment
- Non-production environment
- Production environment
- Shared services

## Guidelines

- Avoid overlapping CIDR blocks
- Reserve space for future growth
- Document any custom subnet allocations
- Track Private Google Access ranges
- Note any IP reservations for specific services
