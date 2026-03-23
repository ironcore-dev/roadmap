# Ironcore Roadmap

[![REUSE status](https://api.reuse.software/badge/github.com/ironcore-dev/roadmap)](https://api.reuse.software/info/github.com/ironcore-dev/roadmap)
[![GitHub License](https://img.shields.io/static/v1?label=License&message=Apache-2.0&color=blue)](LICENSE)

Central tracking repository for roadmap items that represent cross-project initiatives and larger efforts across the Ironcore ecosystem.

---

## Purpose

This repository serves as the **single source of truth for tracking major roadmap items** in the Ironcore ecosystem. The work tracked here consists of initiatives that span across multiple areas (e.g., virtualization, metal automation, networking) and require **coordinated planning and execution**.

Each issue in this repository represents a **high-level roadmap item**, broken down into sub-issues across relevant components or areas. This structure ensures that all efforts align with Ironcore’s overall roadmap, product goals, and organizational visibility.

---

## What Qualifies as a Roadmap Item?

A roadmap item is typically:

- A **cross-area initiative** requiring collaboration across multiple teams or components
- A significant effort within a single area that has a broad or strategic impact
- A **larger, structured effort** that may span multiple weeks or months
- A meaningful improvement that **moves Ironcore forward as a product**
- Something that introduces **new architecture, concepts, or user-facing capabilities**
- Worth tracking in monthly/quarterly reports to stakeholders


Examples:
- “Ironcore as a Product” definition and strategy  
- GPU Support across metal and virtualization layers  
- Secure Boot support in both VM and bare metal environments  
- Scheduling architecture for multi-layered MachinePools  

---

## What’s *Not* a Roadmap Item?

Not everything needs to be tracked here. Avoid adding:

- Minor bug fixes, code refactors, or one-off cleanups  
- Routine CI, dependency, or infra updates  
- Changes limited to a single component that don’t impact broader architecture or UX  

These should be filed in the respective component/project repositories and, if necessary, linked as **sub-issues** under a relevant roadmap item.

---

## Structure

- **Top-level issues** in this repository are roadmap items
- **Each roadmap item** should include:
  - A clear summary of the goal
  - Scope (what’s included/excluded)
  - Acceptance criteria
  - Action items
  - Sub-issues across relevant areas

---

## Contributing

If you have an idea that may qualify as a roadmap item:
1. Validate that it aligns with the roadmap item criteria above
2. Circulate it via internal channels or design meetings
3. File a roadmap item issue here using the relevant issue template in [`.github/ISSUE_TEMPLATE`](./.github/ISSUE_TEMPLATE)
4. Link relevant sub-issues under it as work progresses

For minor monthly work, contribute through the appropriate `[Improvements]` issue for your area.

---

## Contact & Discussions

- Join relevant internal meetings/syncs  
- Open or comment on a roadmap item issue  
- Prefer to use Slack or internal channels for brainstorming
