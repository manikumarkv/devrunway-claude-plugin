# Ant Design Standards

## Install

```bash
npm install antd @ant-design/icons
```

## ConfigProvider + custom theme

```tsx
// app/providers.tsx
"use client";
import { ConfigProvider, theme as antTheme } from "antd";
import enUS from "antd/locale/en_US";

const { defaultAlgorithm, darkAlgorithm } = antTheme;

export function AntdProvider({
  children,
  isDark = false,
}: {
  children: React.ReactNode;
  isDark?: boolean;
}) {
  return (
    <ConfigProvider
      locale={enUS}
      theme={{
        algorithm: isDark ? darkAlgorithm : defaultAlgorithm,
        token: {
          // Brand colors
          colorPrimary: "#3b82f6",
          colorSuccess: "#22c55e",
          colorWarning: "#f59e0b",
          colorError: "#ef4444",
          colorInfo: "#3b82f6",

          // Typography
          fontFamily: "'Inter', system-ui, sans-serif",
          fontSize: 14,
          fontSizeHeading1: 38,
          fontSizeHeading2: 30,
          fontSizeHeading3: 24,

          // Sizing
          borderRadius: 8,
          borderRadiusLG: 12,
          borderRadiusSM: 4,

          // Spacing
          padding: 16,
          paddingLG: 24,
          paddingSM: 12,

          // Motion
          motionDurationMid: "0.15s",
        },
        components: {
          Button: {
            fontWeight: 500,
            paddingInline: 20,
          },
          Table: {
            headerBg: "#f8fafc",
            headerColor: "#374151",
            headerSortActiveBg: "#f1f5f9",
            rowHoverBg: "#f8fafc",
          },
          Form: {
            labelColor: "#374151",
            labelFontSize: 14,
          },
          Input: {
            activeBorderColor: "#3b82f6",
          },
          Modal: {
            titleFontSize: 18,
          },
        },
      }}
    >
      {children}
    </ConfigProvider>
  );
}
```

## Using design tokens in components

```tsx
import { theme } from "antd";

function StyledCard({ children }: { children: React.ReactNode }) {
  const { token } = theme.useToken();

  return (
    <div
      style={{
        backgroundColor: token.colorBgContainer,
        border: `1px solid ${token.colorBorderSecondary}`,
        borderRadius: token.borderRadiusLG,
        padding: token.paddingLG,
        boxShadow: token.boxShadowTertiary,
      }}
    >
      {children}
    </div>
  );
}
```

## Form with validation

```tsx
import { Form, Input, Button, Select, DatePicker, InputNumber } from "antd";

interface CreateUserFormValues {
  email: string;
  fullName: string;
  role: "admin" | "member" | "viewer";
  age: number;
}

interface CreateUserFormProps {
  onSubmit: (values: CreateUserFormValues) => Promise<void>;
}

export function CreateUserForm({ onSubmit }: CreateUserFormProps) {
  const [form] = Form.useForm<CreateUserFormValues>();

  async function handleFinish(values: CreateUserFormValues) {
    await onSubmit(values);
    form.resetFields();
  }

  return (
    <Form
      form={form}
      layout="vertical"
      onFinish={handleFinish}
      validateTrigger="onBlur"
      scrollToFirstError
    >
      <Form.Item
        label="Full Name"
        name="fullName"
        rules={[
          { required: true, message: "Full name is required" },
          { min: 2, message: "Must be at least 2 characters" },
          { max: 100, message: "Must be 100 characters or fewer" },
        ]}
      >
        <Input placeholder="Jane Doe" autoComplete="name" />
      </Form.Item>

      <Form.Item
        label="Email"
        name="email"
        rules={[
          { required: true, message: "Email is required" },
          { type: "email", message: "Enter a valid email" },
        ]}
      >
        <Input type="email" placeholder="jane@example.com" autoComplete="email" />
      </Form.Item>

      <Form.Item
        label="Role"
        name="role"
        rules={[{ required: true, message: "Role is required" }]}
      >
        <Select
          placeholder="Select a role"
          options={[
            { value: "admin", label: "Admin" },
            { value: "member", label: "Member" },
            { value: "viewer", label: "Viewer" },
          ]}
        />
      </Form.Item>

      <Form.Item
        label="Age"
        name="age"
        rules={[
          { required: true, message: "Age is required" },
          { type: "number", min: 18, max: 120, message: "Must be between 18 and 120" },
        ]}
      >
        <InputNumber style={{ width: "100%" }} placeholder="25" />
      </Form.Item>

      <Form.Item>
        <Button type="primary" htmlType="submit" block>
          Create User
        </Button>
      </Form.Item>
    </Form>
  );
}
```

## Table with server-side pagination and sorting

```tsx
import { Table, Tag, Space, Button } from "antd";
import type { ColumnsType, TableProps } from "antd/es/table";
import type { SorterResult } from "antd/es/table/interface";
import { useState, useEffect } from "react";

interface User {
  id: number;
  name: string;
  email: string;
  role: string;
  status: "active" | "inactive";
  createdAt: string;
}

interface PaginationState {
  current: number;
  pageSize: number;
  total: number;
}

interface SortState {
  field?: string;
  order?: "ascend" | "descend";
}

export function UsersTable({
  onEdit,
  onDelete,
}: {
  onEdit: (user: User) => void;
  onDelete: (user: User) => void;
}) {
  const [data, setData] = useState<User[]>([]);
  const [loading, setLoading] = useState(false);
  const [pagination, setPagination] = useState<PaginationState>({ current: 1, pageSize: 20, total: 0 });
  const [sort, setSort] = useState<SortState>({});

  const columns: ColumnsType<User> = [
    {
      title: "Name",
      dataIndex: "name",
      key: "name",
      sorter: true,
      sortOrder: sort.field === "name" ? sort.order : null,
      render: (name: string) => <strong>{name}</strong>,
    },
    {
      title: "Email",
      dataIndex: "email",
      key: "email",
    },
    {
      title: "Role",
      dataIndex: "role",
      key: "role",
      filters: [
        { text: "Admin", value: "admin" },
        { text: "Member", value: "member" },
        { text: "Viewer", value: "viewer" },
      ],
    },
    {
      title: "Status",
      dataIndex: "status",
      key: "status",
      render: (status: User["status"]) => (
        <Tag color={status === "active" ? "success" : "default"}>
          {status.toUpperCase()}
        </Tag>
      ),
    },
    {
      title: "Created",
      dataIndex: "createdAt",
      key: "createdAt",
      sorter: true,
      render: (date: string) => new Date(date).toLocaleDateString(),
    },
    {
      title: "Actions",
      key: "actions",
      width: 140,
      render: (_, record) => (
        <Space>
          <Button size="small" onClick={() => onEdit(record)}>Edit</Button>
          <Button size="small" danger onClick={() => onDelete(record)}>Delete</Button>
        </Space>
      ),
    },
  ];

  async function fetchData(page: number, pageSize: number, sortField?: string, sortOrder?: string) {
    setLoading(true);
    try {
      const params = new URLSearchParams({
        page: String(page),
        pageSize: String(pageSize),
        ...(sortField ? { sortField, sortOrder: sortOrder ?? "asc" } : {}),
      });
      const res = await fetch(`/api/users?${params}`);
      const json = await res.json();
      setData(json.items);
      setPagination((prev) => ({ ...prev, total: json.total }));
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    fetchData(pagination.current, pagination.pageSize, sort.field, sort.order);
  }, [pagination.current, pagination.pageSize, sort.field, sort.order]);

  const handleTableChange: TableProps<User>["onChange"] = (pag, _filters, sorter) => {
    const s = sorter as SorterResult<User>;
    setPagination((prev) => ({ ...prev, current: pag.current ?? 1, pageSize: pag.pageSize ?? 20 }));
    setSort({ field: s.field as string, order: s.order ?? undefined });
  };

  return (
    <Table<User>
      columns={columns}
      dataSource={data}
      rowKey="id"
      loading={loading}
      pagination={{
        current: pagination.current,
        pageSize: pagination.pageSize,
        total: pagination.total,
        showSizeChanger: true,
        showTotal: (total) => `${total} users`,
        pageSizeOptions: ["10", "20", "50"],
      }}
      onChange={handleTableChange}
      scroll={{ x: 800 }}
    />
  );
}
```

## Modal — edit form inside modal

```tsx
import { Modal, Form, Input, message } from "antd";
import { useEffect } from "react";

interface EditUserModalProps {
  open: boolean;
  user: User | null;
  onClose: () => void;
  onSave: (userId: number, data: Partial<User>) => Promise<void>;
}

export function EditUserModal({ open, user, onClose, onSave }: EditUserModalProps) {
  const [form] = Form.useForm();
  const [messageApi, contextHolder] = message.useMessage();

  useEffect(() => {
    if (open && user) {
      form.setFieldsValue({ name: user.name, email: user.email });
    }
  }, [open, user, form]);

  async function handleOk() {
    const values = await form.validateFields();
    try {
      await onSave(user!.id, values);
      messageApi.success("User updated");
      onClose();
    } catch {
      messageApi.error("Failed to update user");
    }
  }

  return (
    <>
      {contextHolder}
      <Modal
        title="Edit User"
        open={open}
        onOk={handleOk}
        onCancel={onClose}
        okText="Save"
        cancelText="Cancel"
        destroyOnClose
        width={480}
      >
        <Form form={form} layout="vertical" style={{ marginTop: 16 }}>
          <Form.Item
            label="Name"
            name="name"
            rules={[{ required: true, message: "Name is required" }]}
          >
            <Input />
          </Form.Item>
          <Form.Item
            label="Email"
            name="email"
            rules={[{ required: true }, { type: "email" }]}
          >
            <Input type="email" />
          </Form.Item>
        </Form>
      </Modal>
    </>
  );
}
```

## Confirm delete with Modal.confirm

```tsx
import { Modal } from "antd";
import { ExclamationCircleFilled } from "@ant-design/icons";

// Use Modal.useModal() in function components
export function useDeleteConfirm() {
  const [modal, contextHolder] = Modal.useModal();

  function confirmDelete(user: User, onConfirm: () => Promise<void>) {
    modal.confirm({
      title: `Delete ${user.name}?`,
      icon: <ExclamationCircleFilled />,
      content: "This action cannot be undone.",
      okText: "Delete",
      okType: "danger",
      cancelText: "Cancel",
      onOk: onConfirm,
    });
  }

  return { confirmDelete, contextHolder };
}

// Usage
function UserActions({ user }: { user: User }) {
  const { confirmDelete, contextHolder } = useDeleteConfirm();

  return (
    <>
      {contextHolder}
      <Button danger onClick={() => confirmDelete(user, async () => { await deleteUser(user.id); })}>
        Delete
      </Button>
    </>
  );
}
```

## Global message / notification

```tsx
// Use App component to get message/notification/modal instances in context
import { App } from "antd";

function useAppMessage() {
  const { message, notification } = App.useApp();
  return { message, notification };
}

// Wrap in App at root
export function AntdProvider({ children }: { children: React.ReactNode }) {
  return (
    <ConfigProvider theme={...}>
      <App>
        {children}
      </App>
    </ConfigProvider>
  );
}

// In a component
function SubmitButton({ onSubmit }: { onSubmit: () => Promise<void> }) {
  const { message } = useAppMessage();

  async function handleClick() {
    try {
      await onSubmit();
      message.success("Saved!");
    } catch {
      message.error("Something went wrong.");
    }
  }

  return <Button onClick={handleClick}>Save</Button>;
}
```

## Dark mode integration

```tsx
"use client";
import { ConfigProvider, theme } from "antd";
import { useEffect, useState } from "react";

export function AntdProvider({ children }: { children: React.ReactNode }) {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    setIsDark(mq.matches);
    const handler = (e: MediaQueryListEvent) => setIsDark(e.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  return (
    <ConfigProvider
      theme={{
        algorithm: isDark ? theme.darkAlgorithm : theme.defaultAlgorithm,
        token: { colorPrimary: "#3b82f6" },
      }}
    >
      {children}
    </ConfigProvider>
  );
}
```

## Common mistakes

| Mistake | Fix |
|---|---|
| No `ConfigProvider` — using default theme | Always wrap with `ConfigProvider` and a custom theme |
| Overriding styles via `.ant-btn { ... }` CSS | Use `components: { Button: { ... } }` in `ConfigProvider` |
| `message.success()` at module scope | Use `message.useMessage()` or `App.useApp()` inside components |
| `Form` without `Form.useForm()` | Always use `const [form] = Form.useForm()` and pass `form` prop |
| Reading form values with `ref` | Use `form.getFieldValue()` or `onFinish` callback |
| No `destroyOnClose` on modal with form | Without it, form state persists after close |
| Array index as `rowKey` in Table | Always use a unique business key: `rowKey="id"` |
| Client-side pagination for large datasets | Use server-side pagination with `onChange` handler |
