# Ironcore Enhancements

Central tracking repository for cross-project initiatives, large-scale enhancements, or epics across the Ironcore ecosystem.

---

## 📌 Purpose

This repository serves as the **single source of truth for tracking major enhancements** in the Ironcore ecosystem. Enhancements are initiatives that span across multiple areas (e.g., virtualization, metal automation, networking) and require **coordinated planning and execution**.

Each issue in this repository represents a **high-level enhancement or epic**, broken down into sub-issues across relevant components or areas. This structure ensures that all efforts align with Ironcore’s overall roadmap, product goals, and organizational visibility.

---

## 🧠 What Qualifies as an Enhancement?

An enhancement is typically:

- A **cross-area initiative** requiring collaboration across multiple teams or components
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

## ❓ What’s *Not* an Enhancement?

Not everything needs to be tracked here. Avoid adding:

- Minor bug fixes, code refactors, or one-off cleanups  
- Routine CI, dependency, or infra updates  
- Changes limited to a single component that don’t impact broader architecture or UX  

These should be filed in the respective component/project repositories and, if necessary, linked as **sub-issues** under a relevant enhancement.

---

## 🗂 Structure

- **Top-level issues** are called _Enhancements_ or _Epics_
- **Each enhancement** includes:
  - A clear summary of the goal
  - Scope (what’s included/excluded)
  - Acceptance criteria
  - Action items
  - Sub-issues across relevant areas
- **Area Tracker Issues** are created monthly to track minor/iterative progress within specific domains (e.g., `[Tracker] Networking – Mar 2025`)
  - These roll over open sub-issues to the next month
  - Useful for internal progress and reporting  

---

## 📅 Monthly Process

At the end of each month:
- All **Area Tracker Issues** are closed  
- Any **open sub-issues** are automatically moved to the next month’s tracker (via GitHub automation)  
- Enhancements are updated with links to sub-issues and progress summaries

---

## 🛠 Contributing

If you have an idea that may qualify as an enhancement:
1. Validate that it aligns with the enhancement criteria above
2. Circulate it via internal channels or design meetings
3. File an enhancement issue here using the [`Epic/Initiative` issue template](./.github/ISSUE_TEMPLATE)
4. Link relevant sub-issues under it as work progresses

For minor monthly work, contribute through the appropriate `[Tracker]` issue for your area.

---

## 🔗 Related Areas

- [ironcore-api](https://github.com/...)  
- [metal-automation](https://github.com/...)  
- [networking](https://github.com/...)  
- [virtualization](https://github.com/...)  
- [product integration](https://github.com/...)

---

## 📣 Contact & Discussions

- Join relevant internal meetings/syncs  
- Open or comment on an enhancement issue  
- Prefer to use Slack or internal channels for brainstorming
