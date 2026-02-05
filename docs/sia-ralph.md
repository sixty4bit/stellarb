## **Directive: Hierarchical Parallel Execution (Epic/Task Orchestrator)**

### **Phase 1: Discovery & Orchestration**

1. **Context Audit:** Consult project memory and the beads tracking system to identify all open Epics.
2. **Dependency Check:** For each open Epic, verify the `blocked_by` status. If an Epic is blocked by an uncompleted dependency, skip and log the status.
3. **Agent Spawning:** For every unblocked Epic, spawn a dedicated **Epic Agent**. Execute these in parallel within environment limits.

### **Phase 2: Task Deconstruction (Epic Agent Logic)**

For each assigned Epic:

* Identify all associated Tasks within the Epic.
* For each Task, spawn a **Task Agent** with a dedicated execution session.
* **Status Update:** Immediately mark the Task as `in-progress` in the beads system.

### **Phase 3: Implementation Workflow (Task Agent Logic)**

Each Task Agent must strictly follow this **Isolation & Verification** pipeline:

1. **Environment Isolation:** Create a fresh git worktree and a feature branch named `task/[task-id]-[description]`.
2. **Test-Driven Development (TDD):** * **Red:** Analyze the task and write a failing RSpec or Minitest that defines the "Done" state.
   * **Green:** Implement the minimal code required in Ruby/Rails (Bootstrap/Hotwire stack) to pass the test.
3. **Refactor & Verify:** Ensure code adheres to 37signals patterns. All tests must pass in the isolated worktree.

### **Phase 4: Timeout & Recursive Deconstruction**

In the event of a **Task Timeout** (the agent reaches session limits before tests pass):

1. **Halt Implementation:** Immediately stop the current coding attempt.
2. **Deconstruction:** The Task Agent must analyze the current complexity and split the failed task into multiple smaller, atomic **Subtasks**.
3. **Beads Transformation:**
   * Create the new Subtasks in the `beads` system.
   * Update the original Timeout Task’s description so it reads as an **Epic** (e.g., "EPIC: [Original Description]").
4. **Cleanup:** Remove the failing worktree.
5. **Re-Orchestration:** Signal the Epic Agent to queue these new Subtasks for immediate processing.

### **Phase 5: Completion & Integration**

Once the Task Agent confirms all tests pass (without timing out):

1. **Status Update:** Mark the Task as `complete` in the beads system.
2. **Persistence:** `git add`, `git commit` with a descriptive message, and push the branch to GitHub.
3. **Integration:** Merge the feature branch into `main`.
4. **Cleanup:** Remove the worktree to maintain environment hygiene.

### **Phase 6: Reporting**

* **Epic Agent:** Once all child tasks for an Epic are completed, finalize the Epic and report: "Epic [ID]: [Name] is now CLOSED".