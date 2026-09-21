"use client"

import type React from "react"
import { useEffect, useState } from "react"
import { X, CheckCircle, AlertCircle, Info } from "lucide-react"

export interface Notification {
    id: string
    type: "success" | "error" | "info"
    message: string
    duration?: number
}

interface NotificationSystemProps {
    notifications?: Notification[]
    onRemove: (id: string) => void
}

export const NotificationSystem: React.FC<NotificationSystemProps> = ({ notifications = [], onRemove }) => {
    return (
        <div className="fixed top-4 right-4 z-[100] space-y-3 max-w-md">
            {notifications.map((notification) => (
                <NotificationItem key={notification.id} notification={notification} onRemove={onRemove} />
            ))}
        </div>
    )
}

const NotificationItem: React.FC<{ notification: Notification; onRemove: (id: string) => void }> = ({
    notification,
    onRemove,
}) => {
    const [isExiting, setIsExiting] = useState(false)

    useEffect(() => {
        const timer = setTimeout(() => {
            setIsExiting(true)
            setTimeout(() => onRemove(notification.id), 300)
        }, notification.duration || 3000)

        return () => clearTimeout(timer)
    }, [notification, onRemove])

    const icons = {
        success: <CheckCircle size={20} className="text-green-400" />,
        error: <AlertCircle size={20} className="text-red-400" />,
        info: <Info size={20} className="text-blue-400" />,
    }

    const colors = {
        success: "border-green-500/30 bg-green-500/10",
        error: "border-red-500/30 bg-red-500/10",
        info: "border-blue-500/30 bg-blue-500/10",
    }

    return (
        <div
            className={`flex items-start gap-3 p-4 rounded-xl bg-[rgb(var(--bg-card))] border ${colors[notification.type]} shadow-2xl transition-all duration-300 ${isExiting ? "opacity-0 translate-x-full" : "opacity-100 translate-x-0"
                }`}
        >
            {icons[notification.type]}
            <p className="flex-1 text-white text-sm">{notification.message}</p>
            <button
                onClick={() => {
                    setIsExiting(true)
                    setTimeout(() => onRemove(notification.id), 300)
                }}
                className="text-gray-400 hover:text-white transition-colors"
            >
                <X size={16} />
            </button>
        </div>
    )
}
